# Relatório Técnico - Benchmark WordPress AWS

## 1. Identificação
- **Nome:** Raul Costa Feitosa 
- **Matrícula:** 2418953  
- **Repositório GitHub:** https://github.com/alminha021/aws-wordpress-load-benchmark

## 2. Abordagem

Este relatório apresenta os resultados de um benchmark de performance de uma aplicação WordPress na AWS, avaliando estratégias de escalabilidade sob restrição orçamentária de US$ 0,50/h para a camada de aplicação. Foram testadas abordagens de scale-up (1× c5.large) e scale-out (8× t3.micro), complementadas por tuning de software, utilizando Locust para simular cargas de 200 a 800 usuários simultâneos. A análise compara throughput (RPS), latência (P95), taxa de erro e custo/hora, identificando a configuração ótima que atende aos SLOs definidos (P95 ≤ 10.000 ms, erro < 1%).

### 2.1 Alterações técnicas implementadas

**AMI dinâmica falhando na inicialização**  
**Problema:** AMI dinâmica não provisionou corretamente (pacotes ausentes, PHP incompatível)  
**Solução:** Migração para AMI fixa customizada (Amazon Linux 2 estável, obtida do console AWS)  
**Alterações:** `deploy_app.sh` e `deploy_generator.sh`

**Instalação do WordPress/PHP com falhas**  
**Problema:** WP-CLI URL com aspas quebradas, pacotes PHP incompletos  
**Correção no `user_data_template.sh`:**  
- `curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar`  
- `yum install -y php-mysqlnd php-json php-xml php-mbstring`

### 2.2 Estratégia adotada

**Caminhos testados (duas estratégias avaliadas):**  
1. Escalabilidade vertical (scale-up) com 1× c5.large  
2. Escalabilidade horizontal (scale-out) com 8× t3.micro + tuning Apache

**Justificativa técnica:**  
- **Baseline 1× t3.micro:** P95 ≈ 6,9 s (200 usuários) - saturação em baixa carga  
- **Scale-up (1× c5.large):** P95 ≈ 6,6 s (200 usuários) - **pouco efetiva**, sem ganho significativo (~24 RPS)  
- **Scale-out (8× t3.micro):** 93,56 RPS, P95 ≈ 140 ms (200 usuários) - **grande ganho**  
- **Otimização final:** 174,64 RPS, P95 ≈ 650 ms, 0% erro (400 usuários) - **SLO atendido**

**Justificativa de custo (us-east-1):**  
t3.micro ≈ **US$ 0,0104/h** | c5.large ≈ **US$ 0,085/h**

| Cenário | Qtd | Custo unitário | Custo total |
|---------|-----|----------------|-------------|
| 1× t3.micro | 1 | $0,0104 | **$0,0104/h** |
| 1× c5.large | 1 | $0,0850 | **$0,0850/h** |
| **8× t3.micro** | 8 | $0,0104 | **$0,0832/h** |

## 3. Arquitetura final

**Instâncias:** 8× t3.micro  
**Stack:** Amazon Linux 2, Apache httpd, PHP, WordPress, Locust  

**Tuning Apache:**  
- `ServerLimit 256`  
- `MaxRequestWorkers 256`  
- `KeepAlive On` / `MaxKeepAliveRequests 200` / `KeepAliveTimeout 2`

**Topologia:** Locust → ALB → 8× WP → RDS MySQL

## 4. Resultados obtidos

### 4.1 Resumo numérico

| Cenário | Usuários | Requests/s | Erro (%) | P95 (ms) | Situação |
|---------|----------|------------|----------|----------|----------|
| 1× t3.micro | 200 | 23,31 | 1,07 | 6900 | Saturado |
| 1× c5.large | 200 | 24,10 | 0,80 | 6600 | Pouco efetivo |
| 8× t3.micro | 200 | 93,56 | 0,00 | 140 | Grande ganho |
| 8× t3.micro | 400 | 175,02 | 0,20 | 560 | Bom |
| **8× t3.micro (tuning)** | **400** | **174,64** | **0,00** | **650** | **Cenário final** |
| 8× t3.micro (tuning) | 800 | 180,03 | 26,74 | 8500 | Acima capacidade |

### 4.2 Métricas principais
- **RPS máximo estável:** 174,64 RPS (erro < 1%, P95 < 10s)  
- **Latência P95:** 650 ms (SLO: ≤ 10.000 ms)  
- **Taxa de erro:** 0% (21.013 requisições)

## 5. Análise de custo

| Cenário | Tipo | Qtd | Preço/h | Total/h |
|---------|------|-----|---------|---------|
| Baseline | t3.micro | 1 | 0,0104 | **0,0104** |
| Scale-up | c5.large | 1 | 0,0850 | **0,0850** |
| **Final** | t3.micro | **8** | **0,0104** | **0,0832** |

**Todos abaixo de US$ 0,50/h** - configuração final equilibra performance e custo.

## 6. Evidências
- https://github.com/alminha021/aws-wordpress-load-benchmark Print Locust (400 usuários, 8× t3.micro tuning)
- resultados em csv dos testes

