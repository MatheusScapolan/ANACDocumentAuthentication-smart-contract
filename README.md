# ANACDocumentAuthentication — Smart Contract para verificação de documentos de embarque internacional

**Atividade Ponderada — Módulo 5 | Blockchain & Software Descentralizado**  
**Instituição:** INTELI — Instituto de Tecnologia e Liderança  
**Eixo:** Computação — Smart Contracts com Solidity  
**Referência normativa:** [ANAC — Documentos para Embarque](https://www.gov.br/anac/pt-br/assuntos/passageiros/documentos-para-embarque)

**Autor:** [Matheus Henrique Scapolan Silva](https://github.com/MatheusScapolan)
---

## Sumário

1. [Contexto e motivação](#1-contexto-e-motivação)
2. [Encaixe no Módulo 5](#2-encaixe-no-módulo-5)
3. [O Problema](#3-o-problema)
4. [Modelagem do Contrato](#4-modelagem-do-contrato)
5. [Tecnologias utilizadas](#5-tecnologias-utilizadas)
6. [Arquitetura da solução](#6-arquitetura-da-solução)
7. [O Contrato](#7-o-contrato)
8. [Como executar no Remix IDE](#8-como-executar-no-remix-ide)
9. [Casos de teste](#9-casos-de-teste)
10. [Conclusão](#10-conclusão)
11. [Referências Bibliográficas](#11-referências-bibliográficas)

---

## 1. Contexto e Motivação

A Agência Nacional de Aviação Civil (ANAC), autarquia federal vinculada ao Ministério de Portos e Aeroportos criada pela Lei n. 11.182, de 27 de setembro de 2005, é o órgão responsável por regular e fiscalizar as atividades de aviação civil no Brasil. Dentre suas atribuições, está a definição dos documentos exigidos para embarque em voos domésticos e internacionais, em conformidade com as normas da Organização de Aviação Civil Internacional (ICAO), da qual o Brasil é Estado membro.

Na prática, a verificação documental no check-in é um processo sujeito a erros: atendentes precisam aplicar corretamente um conjunto de regras que varia conforme a idade do passageiro, sua nacionalidade, o tipo de acompanhante e o país de destino. Segundo dados da IATA (International Air Transport Association, 2022), irregularidades documentais estão entre as principais causas de negativa de embarque em aeroportos ao redor do mundo, gerando prejuízos operacionais e impacto direto na experiência do viajante.

A codificação dessas regras em um contrato inteligente implantado em uma blockchain elimina a ambiguidade interpretativa inerente ao processo manual. As normas passam a ser executadas de forma automática, determinística e auditável, sem depender de um intermediário centralizado. O registro de cada verificação é gravado de forma imutável, criando uma trilha permanente de conformidade. Esse modelo se alinha ao que o Fórum Econômico Mundial descreveu, em seu relatório "Blockchain Beyond the Hype" (World Economic Forum, 2018), como um dos casos de uso de maior impacto social da tecnologia: a verificação descentralizada de credenciais e identidade.

---

## 2. Encaixe no módulo 5

O Módulo 5 do curso de Sistemas de Informação do INTELI é estruturado em cinco eixos — Matemática/Física, Computação, UX, Negócios e Liderança. A presente atividade se insere diretamente no eixo de Computação, mas dialoga com os demais.

**Computação — Blockchain e Smart Contracts**

A atividade é o ponto de convergência prática do conteúdo teórico sobre contratos inteligentes. Conforme definido por Buterin (2014) no Ethereum White Paper, contratos inteligentes são programas armazenados na blockchain que executam automaticamente quando as condições previamente estabelecidas são atendidas, sem necessidade de intermediários. Wood (2014) formaliza esse conceito no Yellow Paper como um "agente autônomo" cujo comportamento é determinístico e verificável por qualquer participante da rede.

A implementação do `ANACDocumentAuthentication` em Solidity exige domínio de conceitos ao módulo: tipos de dados compostos (`structs` e `enums`), gerenciamento de estado on-chain (`mapping`), visibilidade de funções (`external`, `internal`, `pure`, `view`), sistema de eventos para rastreabilidade off-chain, erros customizados (`custom errors`) e boas práticas de otimização como `unchecked`.

**Negócios — Regulação e Tecnologia**

A aplicação de blockchain em contextos de conformidade normativa é um campo em expansão. O mesmo relatório do Fórum Econômico Mundial (2018) identifica a gestão de identidade e a verificação de credenciais como dois dos dez casos de uso de maior impacto. O contrato desenvolvido se posiciona exatamente nessa interseção: uma aplicação descentralizada orientada à conformidade regulatória no setor de aviação civil.

---

## 3. O Problema

### 3.1 Estrutura Normativa da ANAC

A ANAC classifica os viajantes de voos internacionais em três categorias, cada qual com exigências documentais próprias:

**Adultos brasileiros (18 anos ou mais)**

É exigido passaporte brasileiro válido. Para destinos como Argentina, Uruguai, Paraguai, Bolívia, Chile, Peru, Equador, Colômbia e Venezuela, denominados no contrato como "Mercosul estendido", a Carteira de Identidade Civil (RG) emitida pelas Secretarias de Segurança Pública estaduais também é aceita como documento de viagem.

**Crianças e adolescentes brasileiros (0 a 17 anos)**

Esta é a categoria mais complexa, pois a documentação varia conforme o tipo de acompanhante:

- Acompanhados de ambos os pais ou responsável legal: apenas passaporte válido.
- Acompanhados de apenas um dos genitores: passaporte e autorização expressa do outro genitor com firma reconhecida em cartório, assim, dispensada se o passaporte do menor já contiver autorização expressa para viagem ao exterior.
- Desacompanhados ou acompanhados de adulto autorizado pelos responsáveis: passaporte e autorização expressa de ambos os pais ou responsáveis, com firma reconhecida em cartório (podendo ser judicial, extrajudicial ou Autorização Eletrônica de Viagem emitida pelo CNJ). A autorização também é dispensada quando o passaporte contiver autorização expressa.

Para destinos do Mercosul estendido, menores também podem utilizar o RG em substituição ao passaporte.

**Estrangeiros de qualquer idade**

É exigido passaporte do país de origem. Para cidadãos de países do Mercosul estendido, o documento nacional de identidade (equivalente ao RG) também é aceito.

### 3.2 Por que smart contract?

O processo de verificação descrito acima é integralmente determinístico: dados os atributos do passageiro, a documentação necessária é completamente determinada pelas normas da ANAC, sem margem para discricionariedade. Conforme argumentado por Governatori et al. (2018) em "On the Formal Specification of Smart Contracts: A Lawyer's Perspective", normas jurídicas com estrutura condicional clara são candidatas naturais à codificação em contratos inteligentes, pois a computabilidade da norma é condição suficiente para sua automatização segura.

Além do determinismo da lógica, três propriedades intrínsecas da blockchain justificam a escolha tecnológica: imutabilidade, onde cada verificação registrada não pode ser alterada retroativamente; transparência, onde qualquer participante pode verificar as regras codificadas; e desintermediação, onde o contrato opera sem depender de um servidor centralizado sujeito a falhas ou manipulações.

---

## 4. Modelagem do Contrato

Esta seção apresenta a modelagem do `ANACDocumentAuthentication`, percorrendo o cenário em linguagem natural, os atores e ativos envolvidos, as regras que governam o sistema, o estado que o contrato mantém, as operações que ele expõe e as considerações de segurança.

---

### 4.1 Descrição informal do cenário

Imagine um passageiro que vai ao aeroporto para pegar um voo internacional. No balcão de check-in, o atendente precisa conferir se os documentos apresentados estão corretos para aquela viagem específica, e a resposta certa depende de vários fatores ao mesmo tempo: a pessoa é brasileira ou estrangeira? Tem menos de 18 anos? Se for menor, está viajando sozinha, com um dos pais, com os dois, ou com outra pessoa autorizada? O destino é um país que aceita RG ou exige passaporte?

Hoje esse processo depende da memória e atenção do atendente, que pode errar ou aplicar as regras de forma inconsistente. A ideia do contrato `ANACDocumentAuthentication` é colocar essas regras diretamente no código, de forma que qualquer sistema — um totem de autoatendimento, um aplicativo da companhia aérea, um portal de check-in online — possa consultar o contrato e receber imediatamente a lista exata de documentos exigidos para aquele passageiro naquele voo. A resposta será sempre a mesma, não importa quem consulte ou quando: as regras da ANAC, executadas de forma automática e registradas permanentemente na blockchain.

---

### 4.2 Identificação dos atores

Em um contrato inteligente, os "atores" são os endereços Ethereum que interagem com as funções. No `ANACDocumentAuthentication`, não há papéis diferenciados por acesso, qualquer endereço pode chamar qualquer função pública. O que varia é o propósito de quem chama.

| Ator | Descrição | Tipo de interação |
|---|---|---|
| Sistema de check-in da companhia aérea | Principal consumidor esperado do contrato. Envia os dados do passageiro e recebe os documentos exigidos. | `verifyPassenger` (grava histórico) ou `verifyPassengerView` (somente consulta) |
| Passageiro ou usuário final | Pode consultar o contrato diretamente por um DApp para saber o que precisará levar antes de ir ao aeroporto. | `verifyPassengerView` (sem custo de gas) |
| Auditor ou órgão regulatório | Pode consultar o histórico de verificações associado a um endereço para fins de compliance ou auditoria. | `getVerificationCount`, `getVerificationAt` |
| Qualquer endereço externo | O contrato não tem owner, não tem controle de acesso e não guarda saldo — qualquer endereço pode interagir livremente. | Todas as funções públicas |

Vale notar que `msg.sender` — o endereço que assina a transação — é quem fica registrado no histórico de verificações. Se uma companhia aérea opera o sistema, o endereço dela ficará vinculado a cada verificação que realizar, criando uma trilha auditável por operador.

---

### 4.3 Identificação dos ativos

Em contratos DeFi, os ativos costumam ser tokens ou Ether. No `ANACDocumentAuthentication`, o ativo central não é financeiro, eleé informacional.

| Ativo | Descrição | Onde vive |
|---|---|---|
| Registro de verificação (`VerificationResult`) | Cada verificação realizada via `verifyPassenger` gera um registro imutável contendo o resultado, a categoria do passageiro, os documentos exigidos, o timestamp e o endereço que consultou. | `mapping verificationHistory` no storage da blockchain |
| Contador global (`totalVerifications`) | Número acumulado de verificações realizadas em todo o contrato, visível publicamente. | Variável de estado `uint256` |
| Lista do Mercosul estendido (`mercosulCountries`) | Array informativo com os nove países que aceitam RG como documento de viagem, disponível para front-ends e APIs. | Variável de estado `string[]` |
| Regras da ANAC codificadas | A lógica das três categorias de passageiro, com todos os subtipos de acompanhante e distinções de destino, está embutida no próprio código do contrato e é imutável após o deploy. | Bytecode do contrato na EVM |

O contrato não recebe, guarda nem transfere Ether. Não há saldo, não há pagamento, não há risco de perda financeira direta associado ao contrato em si.

---

### 4.4 Levantamento de regras e restrições

As regras abaixo foram extraídas diretamente das normas da ANAC para voos internacionais e estão codificadas no contrato:

**Regras de negócio (ANAC)**

| # | Regra | Categoria |
|---|---|---|
| R1 | Passageiro estrangeiro sempre precisa de passaporte do país de origem | Estrangeiro |
| R2 | Cidadão de país do Mercosul estendido pode usar RG no lugar do passaporte | Estrangeiro / Brasileiro |
| R3 | Adulto brasileiro (>= 18 anos) precisa de passaporte; RG aceito apenas para Mercosul estendido | Adulto BR |
| R4 | Menor com ambos os pais ou responsável legal: apenas passaporte | Menor BR |
| R5 | Menor com um dos pais sem auth. expressa no passaporte: passaporte + autorização do outro genitor | Menor BR |
| R6 | Menor com um dos pais e passaporte com auth. expressa: apenas o passaporte (autorização dispensada) | Menor BR |
| R7 | Menor desacompanhado ou com adulto autorizado, sem auth. no passaporte: passaporte + autorização de ambos os responsáveis | Menor BR |
| R8 | Autorização de ambos pode ser substituída pela Autorização Eletrônica de Viagem (CNJ) | Menor BR |
| R9 | Menor desacompanhado ou com adulto autorizado, com passaporte com auth. expressa: autorização dispensada | Menor BR |
| R10 | Para Mercosul estendido, menores podem usar RG no lugar do passaporte | Menor BR |

**Restrições do contrato**

| # | Restrição | Como é aplicada |
|---|---|---|
| C1 | Idade máxima aceita: 150 anos | `if (age > 150) revert InvalidAge()` na entrada das funções públicas |
| C2 | Índice de histórico não pode exceder o tamanho do array | `if (index >= length) revert IndexOutOfBounds()` em `getVerificationAt` |
| C3 | `_verifyBrazilianMinor` só é chamada para age <= 17 | `if (age > 17) revert InvalidAge()` como guarda interna |
| C4 | Não há controle de acesso: qualquer endereço pode chamar qualquer função | Decisão de design — o contrato é um oráculo público de regras |
| C5 | O contrato não aceita Ether | Nenhuma função é `payable`; envios de Ether causam revert automático |

---

### 4.5 Modelagem do estado

O estado do contrato é o conjunto de dados que persiste na blockchain entre chamadas. No `ANACDocumentAuthentication`, o estado é composto por três elementos:

**`uint256 public totalVerifications`**

Contador simples que cresce a cada chamada de `verifyPassenger`. É público, então qualquer um pode consultá-lo diretamente sem chamar uma função. Serve como métrica de uso do contrato.

**`mapping(address => VerificationResult[]) private verificationHistory`**

O coração do estado do contrato. Para cada endereço que já chamou `verifyPassenger`, existe um array de resultados armazenado. É `private`, então só pode ser acessado pelas funções do próprio contrato — os getters `getVerificationCount` e `getVerificationAt` fazem a interface controlada com o mundo externo.

**`string[] private mercosulCountries`**

Array estático de nove países, populado na declaração da variável. Não é consultado pela lógica interna — serve apenas como dado de referência para front-ends.

**A struct `VerificationResult`**

Cada elemento do histórico é uma struct com seis campos:

```
VerificationResult
|-- canBoard           bool             pode embarcar?
|-- category          PassengerCategory categoria enquadrada (0, 1 ou 2)
|-- requiredDocuments DocumentCode[]   documentos obrigatórios
|-- optionalDocuments DocumentCode[]   documentos aceitos como alternativa
|-- timestamp         uint256          momento do bloco (unix)
`-- verifiedBy        address          quem fez a consulta
```

---

### 4.6 Modelagem das operações

**Funções de verificação (operações principais)**

| Função | Visibilidade | Escreve estado? | Descrição |
|---|---|---|---|
| `verifyPassenger(...)` | `external` | Sim | Verifica documentos, grava resultado no histórico, emite eventos. Custa gas. |
| `verifyPassengerView(...)` | `external view` | Não | Mesma lógica de `verifyPassenger`, sem gravar nada. Gratuito. |

**Funções internas (lógica de negócio)**

| Função | Visibilidade | Categoria |
|---|---|---|
| `_verifyBrazilianAdult(destination)` | `internal pure` | Adulto BR |
| `_verifyBrazilianMinor(age, companionType, destination, passportAuth)` | `internal pure` | Menor BR |
| `_verifyForeigner(destination)` | `internal pure` | Estrangeiro |

Todas são `pure`: não leem nem escrevem estado, são completamente determinísticas.

**Getters auxiliares (consultas)**

| Função | O que retorna |
|---|---|
| `getVerificationCount(user)` | Número de verificações do endereço |
| `getVerificationAt(user, index)` | Verificação específica do histórico |
| `getMercosulCountries()` | Lista dos 9 países do Mercosul estendido |
| `getCategoryName(category)` | Nome da categoria em português |
| `getCompanionTypeName(cType)` | Nome do tipo de acompanhante em português |
| `getDestinationName(dest)` | Nome do grupo de destino em português |
| `getDocumentDescription(code)` | Descrição textual de um DocumentCode |

**Eventos emitidos**

| Evento | Quando é emitido | Campos indexados |
|---|---|---|
| `DocumentVerified` | A cada chamada de `verifyPassenger` | `requester`, `category` |
| `MinorBoardingAlert` | Apenas quando o passageiro é menor de idade | `requester` |

Os eventos são indexados para permitir filtragem eficiente por sistemas externos (como The Graph), sem precisar varrer o histórico inteiro.

---

### 4.7 Verificações de segurança e cenários de falha

**O que acontece se alguém se comportar mal?**

O principal risco em qualquer contrato é a entrada de dados maliciosos ou incorretos. No `ANACDocumentAuthentication`, isso foi tratado da seguinte forma:

*Entrada de idade inválida:* Se um chamador enviar `age = 255` (máximo de `uint8`) ou qualquer valor acima de 150, a função reverte com `InvalidAge()` antes de executar qualquer lógica. Nenhum dado é gravado, nenhum gas além do consumido até o revert é cobrado.

*Índice de histórico fora do intervalo:* Se alguém chamar `getVerificationAt` com um índice maior do que o tamanho do array, a função reverte com `IndexOutOfBounds()`. Isso evita o comportamento indefinido de acessar posições inexistentes em arrays Solidity.

*Envio de Ether ao contrato:* Nenhuma função é `payable`. Qualquer tentativa de enviar Ether ao contrato causa revert automático pela EVM, impedindo que fundos fiquem presos.

*Manipulação do histórico:* O histórico é `private` e só cresce — não existe função para deletar ou alterar registros. Um chamador mal-intencionado poderia acumular verificações no próprio endereço, mas isso apenas aumentaria seu array pessoal sem afetar outros endereços ou a lógica do contrato.

*Parâmetros com valores de enum inexistentes:* Solidity reverte automaticamente se um valor numérico enviado não corresponde a nenhum membro do enum alvo. Por exemplo, enviar `companionType = 9` causa revert antes de entrar na função.

**Como evitar cenários travados?**

Um contrato "travado" é aquele que para de funcionar ou bloqueia fundos de forma irreversível. Os principais riscos dessa natureza foram eliminados por design:

*Sem Ether, sem travamento financeiro:* Como o contrato não guarda Ether, não há risco do bug clássico de fundos bloqueados. Não há `withdraw`, não há `transfer`, não há risco de reentrância financeira.

*Sem dependência de outros contratos:* O contrato não chama endereços externos. Não há risco de reentrância (Atzei, Bartoletti & Cimoli, 2017), onde um contrato malicioso poderia re-entrar na função antes de ela terminar.

*Sem owner, sem risco de chave perdida:* Não existe uma variável `owner` nem funções protegidas por `onlyOwner`. Se a chave do deployer for perdida, o contrato continua funcionando normalmente — não há função administrativa que precise de autorização especial.

*Sem loops sobre arrays de tamanho variável:* O contrato não itera sobre `verificationHistory` em nenhuma função pública. Isso evita o risco de uma função consumir gas demais e reverter por limite de bloco caso o histórico de um endereço cresça muito.

**Limitações conhecidas**

O contrato confia nos dados informados pelo chamador. Se um sistema de check-in informar que o passageiro tem 25 anos quando na verdade tem 14, o contrato retornará as regras de adulto — o que seria incorreto. A validação da veracidade dos dados de entrada é responsabilidade da camada que consome o contrato, não do contrato em si. Isso é uma limitação inerente a oráculos on-chain sem fonte de verdade externa.

---

### 4.8 Ir além — Extensões possíveis

O contrato atual cobre as regras da ANAC para voos internacionais, mas há extensões que poderiam torná-lo ainda mais completo em um cenário de produção real:

**Voos domésticos:** As regras para voos domésticos têm categorias diferentes (brasileiros a partir de 16 anos, crianças até 12 anos incompletos, adolescentes entre 12 e 15 anos). Uma versão estendida poderia receber um parâmetro `flightType` e cobrir ambos os casos.

**Integração com identidade digital:** Com a evolução dos sistemas de identidade descentralizada (DIDs — Decentralized Identifiers), seria possível que o contrato recebesse uma referência verificável à identidade do passageiro em vez de dados brutos, aumentando a confiabilidade das entradas.

**Controle de acesso por operador:** Para uso em produção por companhias aéreas, faria sentido adicionar um sistema de papéis (como o `AccessControl` da OpenZeppelin) que limite quem pode chamar `verifyPassenger` com gravação de histórico, reservando a função transacional apenas a operadores cadastrados.

**Atualização de regras:** As normas da ANAC podem mudar. Um padrão de proxy (como o UUPS da OpenZeppelin) permitiria atualizar a lógica do contrato sem perder o histórico armazenado, resolvendo a tensão entre imutabilidade da blockchain e mutabilidade das normas regulatórias.

**Emissão de certificado NFT:** Após uma verificação bem-sucedida, o contrato poderia emitir um token não-fungível (NFT) que funciona como comprovante digital de conformidade documental para aquele voo específico — algo que a companhia aérea e o passageiro poderiam guardar como evidência auditável.

---

## 5. Tecnologias utilizadas

### 5.1 Solidity

Solidity é uma linguagem de programação de alto nível, com tipagem estática, orientada a contratos e projetada especificamente para a Ethereum Virtual Machine (EVM). Sua sintaxe é influenciada por C++, Python e JavaScript. O contrato `ANACDocumentAuthentication` utiliza a versão `^0.8.20` do compilador, que introduz verificações automáticas de overflow e underflow aritméticos sem necessidade de bibliotecas externas como SafeMath, além de suporte completo a custom errors e otimizações como `unchecked`, conforme documentado pela Ethereum Foundation (2023).

### 5.2 Ethereum virtual machine (EVM)

A EVM é o ambiente de execução sandboxed e determinístico que processa contratos inteligentes na rede Ethereum. Conforme definido por Wood (2014) no Yellow Paper, é uma máquina de Turing completa que garante que a mesma entrada sempre produzirá a mesma saída, independente do nó que a execute. Essa propriedade é central para a confiabilidade do `ANACDocumentAuthentication`: independente de quem interaja com o contrato, as regras da ANAC serão aplicadas de forma idêntica e verificável.

### 5.3 Remix IDE

O Remix IDE é um ambiente de desenvolvimento web baseado em navegador, mantido pela Ethereum Foundation, para compilação, depuração e implantação de contratos Solidity. Conforme sua documentação oficial (Remix Project, 2023), oferece compilador integrado, máquina virtual JavaScript que simula a EVM localmente sem custo real de gas, e depurador passo a passo para inspeção do estado do contrato. É a IDE indicada nos autoestudos do módulo e não requer configuração de ambiente local.

---

## 6. Arquitetura da solução

O contrato é organizado em nove seções sequenciais:

```
ANACDocumentAuthentication.sol
|
|-- SEÇÃO 1: Erros customizados
|     `-- InvalidAge, IndexOutOfBounds
|
|-- SEÇÃO 2: Enumerações
|     |-- Nationality, CompanionType, DestinationCountry, PassengerCategory
|     `-- DocumentCode  (PASSPORT, RG_ESTADUAL, AUTH_ONE_PARENT, ...)
|
|-- SEÇÃO 3: Estrutura
|     `-- VerificationResult  (usa DocumentCode[] em vez de string[])
|
|-- SEÇÃO 4: Estado
|     |-- totalVerifications  (uint256, publico)
|     `-- verificationHistory (mapping address => VerificationResult[])
|
|-- SEÇÃO 5: Lista informativa Mercosul (apenas para front-ends e APIs)
|
|-- SEÇÃO 6: Eventos
|     |-- DocumentVerified
|     `-- MinorBoardingAlert
|
|-- SEÇÃO 7: Logica de negocio (internal pure)
|     |-- _verifyBrazilianAdult(destination)
|     |-- _verifyBrazilianMinor(age, companionType, destination, passportAuth)
|     `-- _verifyForeigner(destination)
|
|-- SEÇÃO 8: Interface publica (external)
|     |-- verifyPassenger(...)       -> grava historico + emite eventos
|     `-- verifyPassengerView(...)   -> somente leitura, sem gas
|
`-- SEÇÃO 9: Getters auxiliares
      |-- getVerificationCount(user)
      |-- getVerificationAt(user, index)
      |-- getMercosulCountries()
      |-- getCategoryName(category)
      |-- getCompanionTypeName(cType)
      |-- getDestinationName(dest)
      `-- getDocumentDescription(code)
```

**Diagrama de decisão (voos internacionais — ANAC)**

```
Passageiro
|-- Estrangeiro
|     |-- Mercosul estendido  --> PASSPORT | ID_MERCOSUL
|     `-- Outros destinos     --> PASSPORT
|
`-- Brasileiro
      |-- Adulto (>= 18 anos)
      |     |-- Mercosul estendido  --> PASSPORT | RG_ESTADUAL
      |     `-- Outros destinos     --> PASSPORT
      |
      `-- Menor (0 a 17 anos)
            |-- Ambos os pais / responsavel  --> PASSPORT
            |-- Um dos pais
            |     |-- Passport c/ auth.      --> PASSPORT_WITH_AUTH
            |     `-- Sem auth.              --> PASSPORT + AUTH_ONE_PARENT
            |-- Adulto autorizado
            |     |-- Passport c/ auth.      --> PASSPORT_WITH_AUTH
            |     `-- Sem auth.              --> PASSPORT + AUTH_BOTH_PARENTS (opt: ETRAVEL_AUTH)
            `-- Desacompanhado
                  |-- Passport c/ auth.      --> PASSPORT_WITH_AUTH
                  `-- Sem auth.              --> PASSPORT + AUTH_BOTH_PARENTS (opt: ETRAVEL_AUTH)

        Para Mercosul estendido (menores): RG_ESTADUAL aceito em lugar do passaporte.
```

---

## 7. O Contrato

### 7.1 Decisões de Design e de Computação

**Por que usar `DocumentCode` em vez de retornar textos?**

Uma das primeiras coisas que aprendi sobre Solidity é que tudo que fica armazenado ou trafega na blockchain tem um custo de gas. Anteriormente o contrato retornava strings longas como `"Passaporte brasileiro valido com autorizacao expressa..."`, mas isso não é uma boa prática, visto que ficaria caro, uma vez que strings em Solidity ocupam espaço byte a byte na memória, e ter arrays cheios delas por verificação é um desperdício real.

A solução foi criar o enum `DocumentCode` com os sete tipos de documento possíveis e retornar apenas os códigos numéricos (tipo `0`, `1`, `2`...). O front-end ou qualquer sistema que consuma o contrato fica responsável por traduzir esses códigos para texto legível, o que é uma separação de responsabilidades parecida com o que é feito em APIs quando é retornado códigos de status em vez de mensagens completas. Para não deixar o contrato totalmente fechado para quem quiser consultar diretamente, também foi criado a função `getDocumentDescription` que faz essa tradução quando necessário.

**Por que usar `error` em vez de `require` com mensagem?**

No começo, era usado `require(age <= 150, "idade invalida")` para validar entradas, que é o jeito mais básico de fazer isso em Solidity. Porém, existe uma forma mais moderna chamada *custom errors*, introduzida no Solidity 0.8.4, que é mais barata em gas porque o erro vira apenas um identificador pequeno ao invés de uma string inteira. Assim, tudo foi trocado para `error InvalidAge()` com `revert`, o que também deixou o código mais limpo e direto.

**O que é o `unchecked` no contador?**

No Solidity 0.8 em diante, toda operação aritmética verifica automaticamente se houve overflow (quando um número passa do limite e volta ao zero). Essa verificação tem um custo. No caso do contador `totalVerifications`, que é um `uint256`, o overflow aconteceria só depois de um número absurdamente grande de operações, o que deixa na prática, impossível. Então foi colocado o incremento dentro de um bloco `unchecked` para desligar essa verificação e economizar um pouco de gas, deixando claro no comentário que foi uma escolha intencional.

**Por que existem duas funções de verificação?**

Qualquer chamada de função que escreve algo na blockchain (que nem o `verifyPassenger`) gera uma transação e cobra gas de quem chamou. Mas às vezes um sistema só precisa consultar o resultado sem precisar guardar nada, sendo assim, um DApp que quer mostrar ao usuário o que ele precisa levar antes de ele confirmar a verificação, por exemplo. Para esses casos, foi criado o `verifyPassengerView`, que é marcado como `view` e por isso não cobra gas. A lógica dos dois é exatamente a mesma, só muda se o resultado é salvo ou não.

**Para que serve o array `mercosulCountries`?**

Primeiramente, seria usado array para validar se um destino é Mercosul ou não dentro da lógica do contrato. Porém, foi percebido que o enum `DestinationCountry` já resolve isso de forma mais limpa e barata. O array ficou no contrato como dado informativo mesmo, assim, um front-end pode chamá-lo para montar um dropdown de países ou exibir a lista para o usuário. Isso foi documentado explicitamente no código para não confundir quem for ler depois.

**Por que dois eventos diferentes?**

Eventos em Solidity são a forma que o contrato tem de "avisar" sistemas externos que algo aconteceu. Foi criado o `DocumentVerified` para toda verificação em geral, e o `MinorBoardingAlert` especificamente para quando o passageiro é menor de idade. Isso facilita a vida de qualquer sistema que precise monitorar o contrato, uma vez queem vez de filtrar todos os eventos e verificar a categoria, ele pode se inscrever só no `MinorBoardingAlert` para tratar menores com a atenção que o caso merece.

**Por que separar a lógica em funções internas?**

As três funções `_verifyBrazilianAdult`, `_verifyBrazilianMinor` e `_verifyForeigner` são marcadas como `internal pure`, ou seja, só podem ser chamadas de dentro do próprio contrato e não mexem com o estado da blockchain. Essa separação foi uma escolha de organização: cada função cuida de uma categoria de passageiro, o que torna o código mais fácil de ler, de testar mentalmente e de modificar sem quebrar as outras partes.

---

### 7.2 Cuidados com Segurança

Algumas práticas de segurança foram aplicadas no contrato:

- Os custom errors `InvalidAge` e `IndexOutOfBounds` garantem que entradas inválidas são rejeitadas antes de qualquer processamento.
- O contrato não chama outros contratos externos e não movimenta Ether, o que evita o principal vetor de ataque em Solidity, conhecido como *reentrancy attack* — onde um contrato malicioso poderia chamar a função de volta antes dela terminar (Atzei, Bartoletti & Cimoli, 2017).
- As funções `pure` e `view` não modificam estado, então são mais previsíveis e mais baratas.
- O compilador 0.8.x cuida automaticamente de overflow e underflow em todo o resto do código.

---

### 7.3 Parâmetros da função principal

| Parâmetro | Tipo | Valores |
|---|---|---|
| `nationality` | `Nationality` | 0 = Brasileiro, 1 = Estrangeiro |
| `age` | `uint8` | 0 a 150 |
| `companionType` | `CompanionType` | 0 = Ambos os pais, 1 = Um dos pais, 2 = Adulto autorizado, 3 = Desacompanhado |
| `destination` | `DestinationCountry` | 0 = Mercosul estendido, 1 = Outros |
| `passportHasExpressAuthorization` | `bool` | true / false |

Retornos:

| Retorno | Tipo | Descrição |
|---|---|---|
| `canBoard` | `bool` | Se pode embarcar com a documentação correta |
| `category` | `PassengerCategory` | Categoria ANAC enquadrada |
| `requiredDocuments` | `DocumentCode[]` | Documentos obrigatórios (códigos) |
| `optionalDocuments` | `DocumentCode[]` | Documentos alternativos aceitos (códigos) |

**Mapeamento de documentCode**

| Código | Significado |
|---|---|
| `PASSPORT (0)` | Passaporte brasileiro válido |
| `PASSPORT_WITH_AUTH (1)` | Passaporte com autorização expressa para o exterior |
| `RG_ESTADUAL (2)` | RG emitido por Secretaria de Segurança Pública estadual |
| `ID_MERCOSUL (3)` | Documento nacional de identidade de país do Mercosul estendido |
| `AUTH_ONE_PARENT (4)` | Autorização do outro genitor com firma reconhecida |
| `AUTH_BOTH_PARENTS (5)` | Autorização de ambos os responsáveis com firma reconhecida |
| `ETRAVEL_AUTH (6)` | Autorização Eletrônica de Viagem (CNJ) |

---

## 8. Como executar no Remix IDE

### Passo 1 — Acessar o Remix

Acesse [https://remix.ethereum.org](https://remix.ethereum.org). Nenhuma instalação é necessária.

### Passo 2 — Criar o arquivo

No painel lateral, clique em "File Explorer" e depois em "New File". Nomeie o arquivo como `ANACDocumentAuthentication.sol` e cole o conteúdo do contrato.

### Passo 3 — Compilar

Clique no ícone "Solidity Compiler". Selecione uma versão compatível com `^0.8.20` (ex: `0.8.24`) e clique em "Compile ANACDocumentAuthentication.sol". Uma marca verde confirma o sucesso.

### Passo 4 — Implantar

Clique em "Deploy & Run Transactions". Em "Environment", selecione "Remix VM (Cancun)" para simular a EVM localmente sem custo real. Clique em "Deploy". O contrato aparecerá em "Deployed Contracts".

### Passo 5 — Interagir

Expanda o contrato para ver as funções. Funções laranjas escrevem na blockchain (transação com gas); funções azuis são somente leitura.

Exemplo — adulto brasileiro para destino genérico:
```
nationality:                     0  (Brazilian)
age:                            35
companionType:                   0  (ignorado para adultos)
destination:                     1  (Other)
passportHasExpressAuthorization: false
```
Retorno esperado: `requiredDocuments = [0]` (PASSPORT)

Exemplo — menor desacompanhado para Argentina sem autorização expressa no passaporte:
```
nationality:                     0  (Brazilian)
age:                            14
companionType:                   3  (Unaccompanied)
destination:                     0  (MercosulExtended)
passportHasExpressAuthorization: false
```
Retorno esperado: `requiredDocuments = [0, 5]` (PASSPORT + AUTH_BOTH_PARENTS), `optionalDocuments = [2, 6]` (RG_ESTADUAL + ETRAVEL_AUTH)

Exemplo — estrangeiro para destino não-Mercosul:
```
nationality:                     1  (Foreigner)
age:                            40
companionType:                   0  (ignorado)
destination:                     1  (Other)
passportHasExpressAuthorization: false
```
Retorno esperado: `requiredDocuments = [0]` (PASSPORT)

Para traduzir os códigos retornados para texto, utilize `getDocumentDescription` passando o código inteiro (ex: `0` para PASSPORT). Para consultas sem custo de gas, utilize `verifyPassengerView` com os mesmos parâmetros. Para consultar o histórico, use `getVerificationCount` com o endereço exibido no campo "Account", depois `getVerificationAt` com o endereço e o índice desejado (base zero).

---

## 9. Casos de teste (para testar no Remix IDE)

| # | Cenário | nationality | age | companionType | destination | passportAuth | requiredDocuments esperados |
|---|---|---|---|---|---|---|---|
| 1 | Adulto BR — destino genérico | 0 | 30 | 0 | 1 | false | [0] PASSPORT |
| 2 | Adulto BR — Mercosul estendido | 0 | 25 | 0 | 0 | false | [0] + opt [2] |
| 3 | Menor BR — com ambos os pais | 0 | 10 | 0 | 1 | false | [0] PASSPORT |
| 4 | Menor BR — um dos pais, sem auth. | 0 | 12 | 1 | 1 | false | [0, 4] |
| 5 | Menor BR — um dos pais, com auth. | 0 | 12 | 1 | 1 | true | [1] PASSPORT_WITH_AUTH |
| 6 | Menor BR — desacompanhado, sem auth. | 0 | 16 | 3 | 1 | false | req: [0, 5] / opt: [6] |
| 7 | Menor BR — desacompanhado, com auth. | 0 | 16 | 3 | 1 | true | [1] PASSPORT_WITH_AUTH |
| 8 | Menor BR — adulto autorizado, Mercosul | 0 | 8 | 2 | 0 | false | req: [0, 5] / opt: [2, 6] |
| 9 | Estrangeiro — destino genérico | 1 | 40 | 0 | 1 | false | [0] PASSPORT |
| 10 | Estrangeiro — Mercosul estendido | 1 | 22 | 0 | 0 | false | [0] + opt [3] |
| 11 | Bebê (0 anos) — com pais | 0 | 0 | 0 | 1 | false | [0] PASSPORT |
| 12 | Limite de menor (17 anos) | 0 | 17 | 0 | 1 | false | [0] PASSPORT |
| 13 | Primeiro adulto (18 anos) | 0 | 18 | 0 | 1 | false | [0] PASSPORT (regras de adulto) |

---

## 10. Conclusão

O desenvolvimento do contrato `ANACDocumentAuthentication` demonstra como normas regulatórias de estrutura condicional determinística podem ser traduzidas em código executável e imutável armazenado em uma blockchain. A lógica normativa da ANAC para voos internacionais, com suas três categorias de passageiros, subtipos de acompanhante para menores, distinção entre destinos do Mercosul estendido e demais países, e regra de dispensa de autorização por passaporte com autorização expressa — é integralmente coberta pelo contrato, sem margens de ambiguidade.

Do ponto de vista da engenharia de contratos inteligentes, a atividade ponderada incorpora práticas de produção também como um a mais no projeto: o uso de `DocumentCode` em vez de `string[]` reduz materialmente o custo de gas ao eliminar a alocação byte a byte de strings longas em memória; os custom errors (`InvalidAge`, `IndexOutOfBounds`) substituem strings em `require`, economizando gas e tornando o código mais expressivo; o `unchecked` no incremento do contador documenta de forma explícita uma decisão de otimização consciente e justificável; e a separação entre função transacional e função `view` permite integrações read-only sem custo

Do ponto de vista conceitual, a atividade evidencia que a blockchain é uma escolha tecnicamente justificada quando os requisitos incluem determinismo da lógica, auditabilidade permanente, transparência e ausência de intermediário de confiança. A codificação de normas em contratos inteligentes não substitui o ordenamento jurídico, mas o complementa com uma camada de execução automática e verificável que aumenta a efetividade das regras. Esse é precisamente o papel desempenhado pelo `ANACDocumentAuthentication` no contexto do processo de verificação documental para embarque em voos internacionais.

---

## 11. Referências Bibliográficas

ATZEI, Nicola; BARTOLETTI, Massimo; CIMOLI, Tiziana. A Survey of Attacks on Ethereum Smart Contracts (SoK). In: **International Conference on Principles of Security and Trust (POST)**. Berlim: Springer, 2017. p. 164–186.

BRASIL. **Lei n. 11.182, de 27 de setembro de 2005**. Cria a Agência Nacional de Aviação Civil — ANAC. Diário Oficial da União, Brasília, 28 set. 2005. Disponível em: https://www.planalto.gov.br/ccivil_03/_ato2004-2006/2005/lei/l11182.htm. Acesso em: fev. 2026.

BRASIL. Agência Nacional de Aviação Civil (ANAC). **Documentos para embarque**. Disponível em: https://www.gov.br/anac/pt-br/assuntos/passageiros/documentos-para-embarque. Acesso em: fev. 2026.

BRASIL. Conselho Nacional de Justiça (CNJ). **Resolução n. 295, de 13 de setembro de 2019**. Regulamenta o procedimento para autorização de viagem de menor ao exterior. Disponível em: https://atos.cnj.jus.br/atos/detalhar/2988. Acesso em: fev. 2026.

BUTERIN, Vitalik. **A Next-Generation Smart Contract and Decentralized Application Platform** (Ethereum White Paper). 2014. Disponível em: https://ethereum.org/en/whitepaper/. Acesso em: fev. 2026.

ETHEREUM FOUNDATION. **Solidity Documentation v0.8.20**. 2023. Disponível em: https://docs.soliditylang.org/en/v0.8.20/. Acesso em: fev. 2026.

ETHEREUM FOUNDATION. **The Merge**. 2022. Disponível em: https://ethereum.org/en/upgrades/merge/. Acesso em: fev. 2026.

GOVERNATORI, Guido et al. On the Formal Specification of Smart Contracts: A Lawyer's Perspective. In: **Proceedings of the 2nd Workshop on Trusted Smart Contracts (WTSC)**. Berlim: Springer, 2018.

IATA — International Air Transport Association. **Passenger Experience Report 2022**. Montreal: IATA, 2022. Disponível em: https://www.iata.org. Acesso em: fev. 2026.

REMIX PROJECT. **Remix IDE Documentation**. 2023. Disponível em: https://remix-ide.readthedocs.io/. Acesso em: fev. 2026.

WOOD, Gavin. **Ethereum: A Secure Decentralised Generalised Transaction Ledger** (Yellow Paper). 2014. Disponível em: https://ethereum.github.io/yellowpaper/paper.pdf. Acesso em: fev. 2026.

WORLD ECONOMIC FORUM. **Blockchain Beyond the Hype: A Practical Framework for Business Leaders**. Genebra: WEF, 2018. Disponível em: https://www3.weforum.org/docs/48423_Whether_Blockchain_WEF_2018.pdf. Acesso em: fev. 2026.

---

*Atividade Ponderada de Computação — Módulo 5 | INTELI — Instituto de Tecnologia e Liderança.*