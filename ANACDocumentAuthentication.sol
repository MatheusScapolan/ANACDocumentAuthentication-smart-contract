// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title  ANACDocumentAuthentication
 * @notice Verifica a documentação necessária para embarque em voos internacionais,
 *         conforme as normas da ANAC publicadas em:
 *         https://www.gov.br/anac/pt-br/assuntos/passageiros/documentos-para-embarque
 *
 * @dev    Três categorias de passageiro são cobertas (voos internacionais):
 *           1. Adultos brasileiros (>= 18 anos)
 *           2. Crianças e adolescentes brasileiros (0 a 17 anos)
 *           3. Estrangeiros de qualquer idade
 *
 *         Em vez de retornar strings longas — o que eleva consideravelmente o custo
 *         de gas — o contrato trabalha com o enum DocumentCode. O front-end ou a
 *         camada off-chain é responsável por traduzir os códigos para texto legível,
 *         separando responsabilidades e reduzindo o consumo on-chain.
 *
 *         Diagrama de decisão (voos internacionais):
 *
 *         Passageiro
 *         |-- Estrangeiro
 *         |     |-- Mercosul estendido  --> PASSPORT | ID_MERCOSUL
 *         |     `-- Outros destinos     --> PASSPORT
 *         |
 *         `-- Brasileiro
 *               |-- Adulto (>= 18 anos)
 *               |     |-- Mercosul estendido  --> PASSPORT | RG_ESTADUAL
 *               |     `-- Outros destinos     --> PASSPORT
 *               |
 *               `-- Menor (0 a 17 anos)
 *                     |-- Ambos os pais / responsável  --> PASSPORT
 *                     |-- Um dos pais
 *                     |     |-- Passaporte c/ auth.    --> PASSPORT_WITH_AUTH
 *                     |     `-- Sem auth.              --> PASSPORT + AUTH_ONE_PARENT
 *                     |-- Adulto autorizado
 *                     |     |-- Passaporte c/ auth.    --> PASSPORT_WITH_AUTH
 *                     |     `-- Sem auth.              --> PASSPORT + AUTH_BOTH_PARENTS (opt: ETRAVEL_AUTH)
 *                     `-- Desacompanhado
 *                           |-- Passaporte c/ auth.    --> PASSPORT_WITH_AUTH
 *                           `-- Sem auth.              --> PASSPORT + AUTH_BOTH_PARENTS (opt: ETRAVEL_AUTH)
 *
 *         Para Mercosul estendido (menores): RG_ESTADUAL aceito em lugar do passaporte.
 */
contract ANACDocumentAuthentication {

    // =========================================================================
    // SEÇÃO 1 — Erros customizados
    // =========================================================================

    /**
     * @dev Erros customizados consomem menos gas do que strings em `require`.
     *      Introduzidos a partir do Solidity 0.8.4.
     */
    error InvalidAge();
    error IndexOutOfBounds();

    // =========================================================================
    // SEÇÃO 2 — Enumerações
    // =========================================================================

    /**
     * @notice Nacionalidade do passageiro.
     *         Determina qual ramificação de regras será aplicada.
     */
    enum Nationality {
        Brazilian,
        Foreigner
    }

    /**
     * @notice Tipo de acompanhante do menor (0–17 anos).
     *         Para adultos e estrangeiros, este campo é ignorado pelo contrato.
     */
    enum CompanionType {
        BothParentsOrGuardian, // ambos os pais ou responsável legal (tutor/guardião)
        OneParentOnly,         // apenas um dos genitores
        AuthorizedAdult,       // adulto (>= 18 anos) autorizado pelos responsáveis
        Unaccompanied          // menor viajando sem acompanhante
    }

    /**
     * @notice Destino da viagem internacional.
     *
     * @dev    MercosulExtended cobre Argentina, Uruguai, Paraguai, Bolívia, Chile,
     *         Peru, Equador, Colômbia e Venezuela — únicos países onde a ANAC aceita
     *         o RG como substituto ao passaporte para brasileiros e estrangeiros desses países.
     *         O array `mercosulCountries` (Seção 5) expõe essa lista para front-ends e
     *         APIs off-chain, mas não interfere na lógica interna do contrato, que resolve
     *         tudo por meio deste enum.
     */
    enum DestinationCountry {
        MercosulExtended,
        Other
    }

    /**
     * @notice Categoria final do passageiro após análise dos dados de entrada.
     *         Corresponde às três categorias da ANAC para voos internacionais.
     */
    enum PassengerCategory {
        BrazilianAdult,
        BrazilianMinor,
        Foreigner
    }

    /**
     * @notice Códigos de documento retornados pelas funções de verificação.
     *
     * @dev    Trabalhar com enum em vez de strings longas reduz significativamente
     *         o custo de gas — strings são alocadas na memória byte a byte.
     *         A tradução para texto legível deve ser feita na camada off-chain
     *         (front-end ou API), separando responsabilidades e mantendo o contrato enxuto.
     *
     *         Mapeamento semântico:
     *           PASSPORT            -> Passaporte brasileiro válido
     *           PASSPORT_WITH_AUTH  -> Passaporte com autorização expressa para o exterior
     *           RG_ESTADUAL         -> RG emitido por Secretaria de Segurança Pública estadual (BR)
     *           ID_MERCOSUL         -> Documento nacional de identidade de país do Mercosul estendido
     *           AUTH_ONE_PARENT     -> Autorização do outro genitor (firma reconhecida em cartório)
     *           AUTH_BOTH_PARENTS   -> Autorização de ambos os responsáveis (firma reconhecida)
     *           ETRAVEL_AUTH        -> Autorização Eletrônica de Viagem (CNJ)
     */
    enum DocumentCode {
        PASSPORT,
        PASSPORT_WITH_AUTH,
        RG_ESTADUAL,
        ID_MERCOSUL,
        AUTH_ONE_PARENT,
        AUTH_BOTH_PARENTS,
        ETRAVEL_AUTH
    }

    // =========================================================================
    // SEÇÃO 3 — Estruturas
    // =========================================================================

    /**
     * @notice Resultado completo de uma verificação de documentos.
     *
     * @param canBoard           Indica se o passageiro pode embarcar (com a documentação correta)
     * @param category           Categoria ANAC enquadrada
     * @param requiredDocuments  Documentos obrigatórios (em códigos — ver DocumentCode)
     * @param optionalDocuments  Documentos aceitos como alternativa
     * @param timestamp          Timestamp do bloco em que a verificação foi registrada
     * @param verifiedBy         Endereço que solicitou a verificação
     */
    struct VerificationResult {
        bool              canBoard;
        PassengerCategory category;
        DocumentCode[]    requiredDocuments;
        DocumentCode[]    optionalDocuments;
        uint256           timestamp;
        address           verifiedBy;
    }

    // =========================================================================
    // SEÇÃO 4 — Variáveis de estado
    // =========================================================================

    /// @notice Contador global de verificações realizadas no contrato.
    uint256 public totalVerifications;

    /**
     * @notice Histórico imutável de verificações por endereço.
     *
     * @dev    A natureza da blockchain garante que nenhum registro pode ser alterado
     *         após a escrita, conferindo auditabilidade total. Cada chamada a
     *         `verifyPassenger` adiciona um novo elemento ao array do endereço.
     */
    mapping(address => VerificationResult[]) private verificationHistory;

    // =========================================================================
    // SEÇÃO 5 — Lista informativa de países do Mercosul estendido
    // =========================================================================

    /**
     * @notice Lista dos países do Mercosul estendido reconhecidos pela ANAC.
     *
     * @dev    Esta lista é meramente informativa para front-ends e APIs off-chain.
     *         A lógica interna do contrato resolve o destino exclusivamente pelo
     *         enum DestinationCountry, sem consultar este array.
     */
    string[] private mercosulCountries = [
        "Argentina", "Uruguay", "Paraguay", "Bolivia",
        "Chile", "Peru", "Ecuador", "Colombia", "Venezuela"
    ];

    // =========================================================================
    // SEÇÃO 6 — Eventos
    // =========================================================================

    /**
     * @notice Emitido a cada verificação concluída.
     *
     * @dev    Indexado por `requester` e `category` para facilitar filtragem off-chain
     *         (ex: The Graph). Eventos são mais baratos em gas do que armazenamento
     *         no storage e são o mecanismo primário de comunicação com o mundo exterior.
     */
    event DocumentVerified(
        address indexed requester,
        PassengerCategory indexed category,
        bool canBoard,
        uint256 timestamp
    );

    /**
     * @notice Emitido especificamente quando um menor de idade é verificado.
     *
     * @dev    Permite que sistemas de compliance configurem alertas dedicados para menores,
     *         sem precisar filtrar o evento geral DocumentVerified por categoria.
     */
    event MinorBoardingAlert(
        address indexed requester,
        uint8 age,
        CompanionType companionType,
        bool canBoard,
        uint256 timestamp
    );

    // =========================================================================
    // SEÇÃO 7 — Lógica de negócio (funções internas)
    // =========================================================================

    /**
     * @notice Avalia os documentos para um adulto brasileiro (>= 18 anos).
     *
     * @dev    Regra ANAC (voos internacionais — adultos brasileiros):
     *           - Passaporte obrigatório para todos os destinos.
     *           - Para Mercosul estendido: RG estadual também é aceito como alternativa.
     *
     *         Declarada como `pure` pois não lê nem modifica o estado da blockchain,
     *         tornando-a previsível, testável de forma isolada e mais barata em gas.
     */
    function _verifyBrazilianAdult(DestinationCountry destination)
        internal
        pure
        returns (
            bool             canBoard,
            DocumentCode[] memory reqDocs,
            DocumentCode[] memory optDocs
        )
    {
        canBoard   = true;
        reqDocs    = new DocumentCode[](1);
        reqDocs[0] = DocumentCode.PASSPORT;

        if (destination == DestinationCountry.MercosulExtended) {
            optDocs    = new DocumentCode[](1);
            optDocs[0] = DocumentCode.RG_ESTADUAL;
        } else {
            optDocs = new DocumentCode[](0);
        }
    }

    /**
     * @notice Avalia os documentos para um menor brasileiro (0–17 anos).
     *
     * @dev    Regra ANAC (voos internacionais — menores brasileiros):
     *
     *         A) BothParentsOrGuardian → apenas PASSPORT
     *         B) OneParentOnly
     *              - passportAuth = true  → PASSPORT_WITH_AUTH
     *              - passportAuth = false → PASSPORT + AUTH_ONE_PARENT
     *         C) AuthorizedAdult | Unaccompanied
     *              - passportAuth = true  → PASSPORT_WITH_AUTH
     *              - passportAuth = false → PASSPORT + AUTH_BOTH_PARENTS
     *                                       (ETRAVEL_AUTH em optionalDocuments — alternativa à autorização em cartório)
     *
     *         Para Mercosul estendido: RG_ESTADUAL aceito em lugar do passaporte.
     *
     *         Fonte: ANAC e Resolução n. 295/2019 do CNJ.
     */
    function _verifyBrazilianMinor(
        uint8              age,
        CompanionType      companionType,
        DestinationCountry destination,
        bool               passportHasExpressAuthorization
    )
        internal
        pure
        returns (
            bool             canBoard,
            DocumentCode[] memory reqDocs,
            DocumentCode[] memory optDocs
        )
    {
        // Guarda de segurança: garante que a função só é chamada para menores.
        if (age > 17) revert InvalidAge();

        canBoard = true;

        // Caso A: ambos os pais ou responsável legal
        if (companionType == CompanionType.BothParentsOrGuardian) {
            reqDocs    = new DocumentCode[](1);
            reqDocs[0] = DocumentCode.PASSPORT;

        // Caso B: apenas um dos genitores
        } else if (companionType == CompanionType.OneParentOnly) {
            if (passportHasExpressAuthorization) {
                reqDocs    = new DocumentCode[](1);
                reqDocs[0] = DocumentCode.PASSPORT_WITH_AUTH;
            } else {
                reqDocs    = new DocumentCode[](2);
                reqDocs[0] = DocumentCode.PASSPORT;
                reqDocs[1] = DocumentCode.AUTH_ONE_PARENT;
            }

        // Casos C e D: adulto autorizado ou desacompanhado — mesma exigência documental
        } else {
            if (passportHasExpressAuthorization) {
                reqDocs    = new DocumentCode[](1);
                reqDocs[0] = DocumentCode.PASSPORT_WITH_AUTH;
            } else {
                // Passaporte + autorização de ambos os responsáveis.
                // ETRAVEL_AUTH vai para optionalDocuments pois é alternativa à autorização em cartório,
                // não um documento adicional — a ANAC aceita OU cartório OU Autorização Eletrônica de Viagem.
                reqDocs    = new DocumentCode[](2);
                reqDocs[0] = DocumentCode.PASSPORT;
                reqDocs[1] = DocumentCode.AUTH_BOTH_PARENTS;
            }
        }

        // Monta optionalDocuments combinando alternativas de passaporte (Mercosul) e de autorização (ETRAVEL_AUTH).
        // ETRAVEL_AUTH só é alternativa relevante quando AUTH_BOTH_PARENTS está em requiredDocuments,
        // ou seja, nos casos C/D sem passportHasExpressAuthorization.
        bool needsAuthAlternative = (
            (companionType == CompanionType.AuthorizedAdult || companionType == CompanionType.Unaccompanied)
            && !passportHasExpressAuthorization
        );

        if (destination == DestinationCountry.MercosulExtended && needsAuthAlternative) {
            optDocs    = new DocumentCode[](2);
            optDocs[0] = DocumentCode.RG_ESTADUAL;
            optDocs[1] = DocumentCode.ETRAVEL_AUTH;
        } else if (destination == DestinationCountry.MercosulExtended) {
            optDocs    = new DocumentCode[](1);
            optDocs[0] = DocumentCode.RG_ESTADUAL;
        } else if (needsAuthAlternative) {
            optDocs    = new DocumentCode[](1);
            optDocs[0] = DocumentCode.ETRAVEL_AUTH;
        } else {
            optDocs = new DocumentCode[](0);
        }
    }

    /**
     * @notice Avalia os documentos para um estrangeiro (qualquer idade).
     *
     * @dev    Regra ANAC (voos internacionais — estrangeiros):
     *           - Passaporte obrigatório para todos os destinos.
     *           - Para Mercosul estendido: documento nacional de identidade do país de origem também aceito.
     *
     *         Em caso de extravio: Decreto n. 5.978/2006 ou consulado/embaixada do país de origem.
     */
    function _verifyForeigner(DestinationCountry destination)
        internal
        pure
        returns (
            bool             canBoard,
            DocumentCode[] memory reqDocs,
            DocumentCode[] memory optDocs
        )
    {
        canBoard   = true;
        reqDocs    = new DocumentCode[](1);
        reqDocs[0] = DocumentCode.PASSPORT;

        if (destination == DestinationCountry.MercosulExtended) {
            optDocs    = new DocumentCode[](1);
            optDocs[0] = DocumentCode.ID_MERCOSUL;
        } else {
            optDocs = new DocumentCode[](0);
        }
    }

    // =========================================================================
    // SEÇÃO 8 — Funções públicas principais
    // =========================================================================

    /**
     * @notice Verifica a documentação do passageiro e registra o resultado na blockchain.
     *
     * @dev    Esta função escreve estado (transação com custo de gas).
     *         Use `verifyPassengerView` para consultas sem custo de gas.
     *
     *         Fluxo:
     *           1. Validação de entrada
     *           2. Roteamento para a função interna conforme nationality + age
     *           3. Persistência do resultado em verificationHistory
     *           4. Incremento do contador (unchecked: overflow praticamente impossível)
     *           5. Emissão de eventos
     *
     * @param nationality                    0 = Brasileiro, 1 = Estrangeiro
     * @param age                            Idade em anos completos (0–150)
     * @param companionType                  Tipo de acompanhante — relevante apenas para menores (0–3)
     * @param destination                    0 = Mercosul estendido, 1 = Outros
     * @param passportHasExpressAuthorization Passaporte do menor tem autorização expressa? (ignorado para adultos)
     *
     * @return canBoard             Se pode embarcar com a documentação correta
     * @return category             Categoria ANAC enquadrada
     * @return requiredDocuments    Documentos obrigatórios (códigos DocumentCode)
     * @return optionalDocuments    Documentos alternativos aceitos
     */
    function verifyPassenger(
        Nationality        nationality,
        uint8              age,
        CompanionType      companionType,
        DestinationCountry destination,
        bool               passportHasExpressAuthorization
    )
        external
        returns (
            bool                  canBoard,
            PassengerCategory     category,
            DocumentCode[] memory requiredDocuments,
            DocumentCode[] memory optionalDocuments
        )
    {
        if (age > 150) revert InvalidAge();

        DocumentCode[] memory reqDocs;
        DocumentCode[] memory optDocs;

        if (nationality == Nationality.Foreigner) {
            category = PassengerCategory.Foreigner;
            (canBoard, reqDocs, optDocs) = _verifyForeigner(destination);

        } else if (age >= 18) {
            category = PassengerCategory.BrazilianAdult;
            (canBoard, reqDocs, optDocs) = _verifyBrazilianAdult(destination);

        } else {
            category = PassengerCategory.BrazilianMinor;
            (canBoard, reqDocs, optDocs) = _verifyBrazilianMinor(
                age,
                companionType,
                destination,
                passportHasExpressAuthorization
            );

            emit MinorBoardingAlert(msg.sender, age, companionType, canBoard, block.timestamp);
        }

        verificationHistory[msg.sender].push(VerificationResult({
            canBoard:          canBoard,
            category:          category,
            requiredDocuments: reqDocs,
            optionalDocuments: optDocs,
            timestamp:         block.timestamp,
            verifiedBy:        msg.sender
        }));

        // unchecked: overflow em uint256 é praticamente impossível no contexto de uso
        unchecked { totalVerifications++; }

        emit DocumentVerified(msg.sender, category, canBoard, block.timestamp);

        return (canBoard, category, reqDocs, optDocs);
    }

    /**
     * @notice Replica exatamente a lógica de `verifyPassenger`, garantindo consistência,
     *         mas sem escrever estado na blockchain, assim, portanto sem custo de gas.
     *
     * @dev    Útil para DApps e integrações read-only que precisam simular o resultado
     *         antes de decidir se registram a verificação definitivamente.
     */
    function verifyPassengerView(
        Nationality        nationality,
        uint8              age,
        CompanionType      companionType,
        DestinationCountry destination,
        bool               passportHasExpressAuthorization
    )
        external
        view
        returns (
            bool                  canBoard,
            PassengerCategory     category,
            DocumentCode[] memory requiredDocuments,
            DocumentCode[] memory optionalDocuments
        )
    {
        if (age > 150) revert InvalidAge();

        DocumentCode[] memory reqDocs;
        DocumentCode[] memory optDocs;

        if (nationality == Nationality.Foreigner) {
            category = PassengerCategory.Foreigner;
            (canBoard, reqDocs, optDocs) = _verifyForeigner(destination);

        } else if (age >= 18) {
            category = PassengerCategory.BrazilianAdult;
            (canBoard, reqDocs, optDocs) = _verifyBrazilianAdult(destination);

        } else {
            category = PassengerCategory.BrazilianMinor;
            (canBoard, reqDocs, optDocs) = _verifyBrazilianMinor(
                age,
                companionType,
                destination,
                passportHasExpressAuthorization
            );
        }

        return (canBoard, category, reqDocs, optDocs);
    }

    // =========================================================================
    // SEÇÃO 9 — Getters auxiliares
    // =========================================================================

    /// @notice Retorna o número de verificações registradas para um endereço.
    function getVerificationCount(address user) external view returns (uint256) {
        return verificationHistory[user].length;
    }

    /**
     * @notice Retorna uma verificação específica do histórico de um endereço.
     * @param user  Endereço Ethereum
     * @param index Índice base zero (0 = primeira verificação do endereço)
     */
    function getVerificationAt(address user, uint256 index)
        external
        view
        returns (VerificationResult memory)
    {
        if (index >= verificationHistory[user].length) revert IndexOutOfBounds();
        return verificationHistory[user][index];
    }

    /// @notice Retorna a lista informativa de países do Mercosul estendido (para front-ends e APIs).
    function getMercosulCountries() external view returns (string[] memory) {
        return mercosulCountries;
    }

    /// @notice Converte PassengerCategory para string legível em português.
    function getCategoryName(PassengerCategory category) external pure returns (string memory) {
        if (category == PassengerCategory.BrazilianAdult) return "Adulto Brasileiro (18 anos ou mais)";
        if (category == PassengerCategory.BrazilianMinor) return "Menor Brasileiro (0 a 17 anos)";
        return "Estrangeiro (qualquer idade)";
    }

    /// @notice Converte CompanionType para string legível em português.
    function getCompanionTypeName(CompanionType cType) external pure returns (string memory) {
        if (cType == CompanionType.BothParentsOrGuardian) return "Ambos os pais ou responsavel legal";
        if (cType == CompanionType.OneParentOnly)         return "Apenas um dos genitores";
        if (cType == CompanionType.AuthorizedAdult)       return "Adulto autorizado pelos responsaveis";
        return "Desacompanhado";
    }

    /// @notice Converte DestinationCountry para string legível.
    function getDestinationName(DestinationCountry dest) external pure returns (string memory) {
        if (dest == DestinationCountry.MercosulExtended)
            return "Mercosul Estendido (Argentina, Uruguai, Paraguai, Bolivia, Chile, Peru, Equador, Colombia, Venezuela)";
        return "Outros destinos internacionais";
    }

    /**
     * @notice Traduz um DocumentCode para sua descrição textual em português.
     *
     * @dev    A tradução de códigos para texto é responsabilidade da camada off-chain por padrão,
     *         evitando o custo de strings longas em memória. Esta função existe como fallback
     *         para integradores simples ou ambientes sem camada lógica própria — situações em
     *         que chamar o contrato diretamente é mais prático do que manter um mapeamento externo.
     */
    function getDocumentDescription(DocumentCode code) external pure returns (string memory) {
        if (code == DocumentCode.PASSPORT)
            return "Passaporte brasileiro valido";
        if (code == DocumentCode.PASSPORT_WITH_AUTH)
            return "Passaporte brasileiro valido contendo autorizacao expressa para viajar ao exterior";
        if (code == DocumentCode.RG_ESTADUAL)
            return "Carteira de Identidade Civil (RG) emitida pelas Secretarias de Seguranca Publica dos Estados ou do Distrito Federal";
        if (code == DocumentCode.ID_MERCOSUL)
            return "Documento nacional de identidade do pais de origem (cidadaos do Mercosul estendido)";
        if (code == DocumentCode.AUTH_ONE_PARENT)
            return "Autorizacao expressa do outro genitor com firma reconhecida em cartorio (judicial ou extrajudicial)";
        if (code == DocumentCode.AUTH_BOTH_PARENTS)
            return "Autorizacao expressa de AMBOS os pais ou responsaveis com firma reconhecida em cartorio (judicial ou extrajudicial)";
        return "Autorizacao Eletronica de Viagem emitida pelo CNJ (alternativa as autorizacoes em cartorio)";
    }
}
