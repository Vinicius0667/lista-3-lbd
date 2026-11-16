-- ============================================================
-- Clínica Veterinária Patas do Cerrado, versão PostgreSQL
-- LBD 2026/2, banco base da Lista de Exercícios de Views
-- Mesmo modelo e mesma carga do gabarito-veterinaria-2026-2.sql (MySQL).
--
-- Rodar no container da disciplina:
--   docker exec -i lbd-postgres psql -U lbd -d lbd < veterinaria-postgresql-2026-2.sql
--
-- Diferenças em relação ao MySQL:
--   * sem CREATE DATABASE / USE: o script roda no banco em que você conectou
--   * sem ENGINE = InnoDB
--   * ENUM do turno virou CHECK ... IN (...)
--   * o script apaga e recria as tabelas: rode de novo para voltar ao estado inicial
-- ============================================================

DROP TABLE IF EXISTS prescricao, consulta, alergia_animal, animal, telefone_tutor,
                     atendente, veterinario, medicamento, consultorio, funcionario,
                     tutor CASCADE;


-- ------------------------------------------------------------
-- Regra 1: Entidades fortes
-- Atributo composto (endereco) é achatado em colunas.
-- ------------------------------------------------------------

CREATE TABLE tutor (
  cpf        CHAR(11)     NOT NULL,
  nome       VARCHAR(100) NOT NULL,
  end_rua    VARCHAR(80)  NOT NULL,
  end_numero VARCHAR(10)  NOT NULL,
  end_bairro VARCHAR(60)  NOT NULL,
  end_cidade VARCHAR(60)  NOT NULL,
  end_uf     CHAR(2)      NOT NULL,
  CONSTRAINT pk_tutor PRIMARY KEY (cpf)
);

CREATE TABLE funcionario (
  cpf     CHAR(11)      NOT NULL,
  nome    VARCHAR(100)  NOT NULL,
  salario DECIMAL(10,2) NOT NULL,
  CONSTRAINT pk_funcionario PRIMARY KEY (cpf),
  CONSTRAINT ck_funcionario_salario CHECK (salario > 0)
);

CREATE TABLE consultorio (
  numero INT         NOT NULL,
  ala    VARCHAR(30) NOT NULL,
  CONSTRAINT pk_consultorio PRIMARY KEY (numero)
);

CREATE TABLE medicamento (
  nome_comercial  VARCHAR(80)   NOT NULL,
  principio_ativo VARCHAR(80)   NOT NULL,
  preco           DECIMAL(10,2) NOT NULL,
  CONSTRAINT pk_medicamento PRIMARY KEY (nome_comercial),
  CONSTRAINT ck_medicamento_preco CHECK (preco >= 0)
);

-- ------------------------------------------------------------
-- Regra 6: Atributo multivalorado do TUTOR vira tabela própria;
-- PK composta (dono + valor)
-- ------------------------------------------------------------

CREATE TABLE telefone_tutor (
  cpf_tutor CHAR(11)    NOT NULL,
  telefone  VARCHAR(20) NOT NULL,
  CONSTRAINT pk_telefone_tutor PRIMARY KEY (cpf_tutor, telefone),
  CONSTRAINT fk_telefone_tutor_tutor FOREIGN KEY (cpf_tutor)
    REFERENCES tutor (cpf)
);

-- ------------------------------------------------------------
-- Regra 2: Entidade fraca (1º nível). PK = chave do dono (tutor) +
-- discriminante (nome do animal). O nome só precisa ser único DENTRO
-- do tutor — é exatamente isso que a PK composta garante; dois tutores
-- podem, cada um, ter um animal chamado "Mel".
-- idade (derivado) NÃO vira coluna: é calculada na consulta (regra 1).
-- ------------------------------------------------------------

CREATE TABLE animal (
  cpf_tutor       CHAR(11)    NOT NULL,
  nome            VARCHAR(60) NOT NULL,
  especie         VARCHAR(30) NOT NULL,
  raca            VARCHAR(40) NOT NULL,
  data_nascimento DATE        NOT NULL,
  CONSTRAINT pk_animal PRIMARY KEY (cpf_tutor, nome),
  CONSTRAINT fk_animal_tutor FOREIGN KEY (cpf_tutor)
    REFERENCES tutor (cpf)
);

-- ------------------------------------------------------------
-- Regra 6: Atributo multivalorado do ANIMAL (que já é uma entidade
-- fraca) vira tabela própria; a PK herda as DUAS colunas do dono
-- (cpf_tutor, nome_animal) + o próprio valor da alergia.
-- ------------------------------------------------------------

CREATE TABLE alergia_animal (
  cpf_tutor   CHAR(11)    NOT NULL,
  nome_animal VARCHAR(60) NOT NULL,
  alergia     VARCHAR(60) NOT NULL,
  CONSTRAINT pk_alergia_animal PRIMARY KEY (cpf_tutor, nome_animal, alergia),
  CONSTRAINT fk_alergia_animal_animal FOREIGN KEY (cpf_tutor, nome_animal)
    REFERENCES animal (cpf_tutor, nome)
);

-- ------------------------------------------------------------
-- Regra 7: Especialização total disjunta (estratégia c: superclasse +
-- subclasses; a PK da subclasse é também FK para a superclasse).
-- A estratégia (c) não IMPEDE sozinha um funcionário órfão (nem
-- veterinário, nem atendente) — enforçar a totalidade exigiria um
-- TRIGGER ou uma consulta de auditoria periódica; discutido em aula
-- como alternativa a um discriminador NOT NULL (estratégia a).
--
-- Regra 4 (auto-relacionamento MENTORIA): crmv_mentor referencia o
-- CANDIDATE KEY crmv (não a PK cpf) — é o vocabulário do próprio
-- minimundo ("mentor é outro veterinário", identificado pelo CRMV).
-- Aceita NULL: único NULL legítimo do esquema, para os veterinários
-- mais antigos, que não têm mentor.
--
-- Regra 3 (1:1 OCUPA, parcial × parcial): nem veterinário nem
-- consultório têm participação total (há volantes e salas vagas), então
-- não há um lado "óbvio" para herdar a FK. Escolhemos colocar
-- numero_consultorio + UNIQUE em veterinario — na prática da clínica, a
-- pergunta mais comum é "em que sala o Dr. Fulano atende?", não o
-- inverso; a alternativa (FK em consultorio, ou uma tabela de
-- associação própria) seria igualmente correta.
-- ------------------------------------------------------------

CREATE TABLE veterinario (
  cpf                CHAR(11)    NOT NULL,
  crmv               VARCHAR(20) NOT NULL,
  especialidade      VARCHAR(60) NOT NULL,
  crmv_mentor        VARCHAR(20)     NULL,
  numero_consultorio INT             NULL,
  CONSTRAINT pk_veterinario PRIMARY KEY (cpf),
  CONSTRAINT uq_veterinario_crmv UNIQUE (crmv),
  CONSTRAINT uq_veterinario_consultorio UNIQUE (numero_consultorio),
  CONSTRAINT fk_veterinario_funcionario FOREIGN KEY (cpf)
    REFERENCES funcionario (cpf),
  CONSTRAINT fk_veterinario_mentor FOREIGN KEY (crmv_mentor)
    REFERENCES veterinario (crmv),
  CONSTRAINT fk_veterinario_consultorio FOREIGN KEY (numero_consultorio)
    REFERENCES consultorio (numero)
);

CREATE TABLE atendente (
  cpf       CHAR(11)    NOT NULL,
  matricula VARCHAR(20) NOT NULL,
  turno     VARCHAR(5)  NOT NULL CHECK (turno IN ('manha','tarde','noite')),
  CONSTRAINT pk_atendente PRIMARY KEY (cpf),
  CONSTRAINT uq_atendente_matricula UNIQUE (matricula),
  CONSTRAINT fk_atendente_funcionario FOREIGN KEY (cpf)
    REFERENCES funcionario (cpf)
);

-- ------------------------------------------------------------
-- Regra 2: Entidade fraca de entidade fraca (2º nível). CONSULTA é
-- fraca de ANIMAL, que já é fraco de TUTOR — a PK herda EM CASCATA as
-- duas colunas de animal (cpf_tutor, nome) e acrescenta o próprio
-- discriminante (data, hora): 4 colunas ao todo.
-- Regra 4: Relacionamento 1:N regular (ATENDE). FK no lado N
-- (consulta); NOT NULL porque toda consulta tem exatamente um
-- veterinário responsável (participação total de consulta em ATENDE).
-- ------------------------------------------------------------

CREATE TABLE consulta (
  cpf_tutor       CHAR(11) NOT NULL,
  nome_animal     VARCHAR(60) NOT NULL,
  data            DATE     NOT NULL,
  hora            TIME     NOT NULL,
  peso            DECIMAL(6,2) NOT NULL,
  diagnostico     VARCHAR(255) NOT NULL,
  cpf_veterinario CHAR(11) NOT NULL,
  CONSTRAINT pk_consulta PRIMARY KEY (cpf_tutor, nome_animal, data, hora),
  CONSTRAINT fk_consulta_animal FOREIGN KEY (cpf_tutor, nome_animal)
    REFERENCES animal (cpf_tutor, nome),
  CONSTRAINT fk_consulta_veterinario FOREIGN KEY (cpf_veterinario)
    REFERENCES veterinario (cpf),
  CONSTRAINT ck_consulta_peso CHECK (peso > 0)
);

-- ------------------------------------------------------------
-- Regra 5: Relacionamento N:M (PRESCREVE) vira tabela associativa.
-- PK = FK composta de 4 colunas para consulta (que já é fraca de
-- fraca!) + FK de 1 coluna para medicamento = 5 colunas na PK.
-- Os dois atributos do relacionamento (dosagem, duracao_dias) viram
-- colunas comuns.
-- ------------------------------------------------------------

CREATE TABLE prescricao (
  cpf_tutor      CHAR(11)    NOT NULL,
  nome_animal    VARCHAR(60) NOT NULL,
  data           DATE        NOT NULL,
  hora           TIME        NOT NULL,
  nome_comercial VARCHAR(80) NOT NULL,
  dosagem        VARCHAR(60) NOT NULL,
  duracao_dias   INT         NOT NULL,
  CONSTRAINT pk_prescricao PRIMARY KEY (cpf_tutor, nome_animal, data, hora, nome_comercial),
  CONSTRAINT fk_prescricao_consulta FOREIGN KEY (cpf_tutor, nome_animal, data, hora)
    REFERENCES consulta (cpf_tutor, nome_animal, data, hora),
  CONSTRAINT fk_prescricao_medicamento FOREIGN KEY (nome_comercial)
    REFERENCES medicamento (nome_comercial),
  CONSTRAINT ck_prescricao_duracao CHECK (duracao_dias > 0)
);

-- ============================================================
-- CARGA: a ORDEM importa, pais antes de filhos (FKs!)
-- tutor/funcionario/consultorio/medicamento → telefone/animal/
-- veterinario/atendente → alergia/consulta → prescricao
--
-- Casos estruturais exercitados de propósito:
--   * "Mel" é animal de dois tutores diferentes (Ana e Carla) — nome só
--     é único DENTRO do tutor.
--   * Helena e Ricardo são veterinários antigos: crmv_mentor = NULL.
--   * Juliana e Otávio são recém-contratados, ambos mentorados por
--     Helena (1 mentor : N mentorados).
--   * Helena e Juliana têm consultório fixo; Ricardo e Otávio são
--     volantes (numero_consultorio = NULL); o consultório 103 fica vago.
--   * Patrícia é atendente (não entra em MENTORIA nem em CONSULTA).
--   * Simba tem 1 alergia, Thor tem 2, os demais animais têm 0.
-- ============================================================

INSERT INTO tutor (cpf, nome, end_rua, end_numero, end_bairro, end_cidade, end_uf) VALUES
('22222222201', 'Ana Beatriz Cortes',  'Rua Ceará',           '145',  'Centro',           'Campo Grande', 'MS'),
('22222222202', 'Bruno Salviano',      'Av. Mato Grosso',     '2200', 'Carandá Bosque',   'Campo Grande', 'MS'),
('22222222203', 'Carla Fragoso',       'Rua Bahia',           '87',   'Jardim dos Estados','Campo Grande', 'MS'),
('22222222204', 'Diego Aquino',        'Rua 26 de Agosto',    '410',  'Amambaí',          'Campo Grande', 'MS');

INSERT INTO funcionario (cpf, nome, salario) VALUES
('33333333301', 'Helena Vasques',       9000.00),
('33333333302', 'Ricardo Bittencourt',  8500.00),
('33333333303', 'Juliana Prates',       6000.00),
('33333333304', 'Otávio Neves',         6200.00),
('33333333305', 'Patrícia Lemos',       3200.00);

INSERT INTO consultorio (numero, ala) VALUES
(101, 'Ala A'),
(102, 'Ala A'),
(103, 'Ala B');  -- vago: nenhum veterinário referencia 103

INSERT INTO medicamento (nome_comercial, principio_ativo, preco) VALUES
('Vetmedin',        'Pimobendana',  89.90),
('Simparic',        'Sarolaner',    65.00),
('Meloxivet',        'Meloxicam',    32.50),
('Amoxilina Pet',    'Amoxicilina',  28.00),
('Flancox',          'Fenbendazol',  15.90);

INSERT INTO telefone_tutor (cpf_tutor, telefone) VALUES
('22222222201', '67 99911-1001'),
('22222222201', '67 3321-1001'),
('22222222202', '67 99911-1002'),
('22222222203', '67 99911-1003'),
('22222222203', '67 98111-1003'),
('22222222204', '67 99911-1004');

-- Especialização: veterinario/atendente referenciam funcionario (total:
-- todo funcionario cadastrado aqui é um dos dois — Patrícia é atendente)
INSERT INTO veterinario (cpf, crmv, especialidade, crmv_mentor, numero_consultorio) VALUES
('33333333301', 'CRMV-MS 0111', 'Clínica geral',  NULL,           101),
('33333333302', 'CRMV-MS 0122', 'Cirurgia',        NULL,           NULL),
('33333333303', 'CRMV-MS 0245', 'Dermatologia',    'CRMV-MS 0111', 102),
('33333333304', 'CRMV-MS 0250', 'Clínica geral',   'CRMV-MS 0111', NULL);

INSERT INTO atendente (cpf, matricula, turno) VALUES
('33333333305', 'ATD-001', 'manha');

INSERT INTO animal (cpf_tutor, nome, especie, raca, data_nascimento) VALUES
('22222222201', 'Mel',     'Canina', 'SRD',        '2021-05-10'),
('22222222201', 'Simba',   'Felina', 'Persa',      '2019-08-01'),
('22222222202', 'Thor',    'Canina', 'Labrador',   '2020-01-15'),
('22222222203', 'Mel',     'Felina', 'SRD',        '2022-02-20'),  -- mesmo nome, tutor diferente
('22222222203', 'Pantera', 'Canina', 'Rottweiler', '2018-11-11'),
('22222222204', 'Fred',    'Ave',    'Calopsita',  '2023-03-03');

INSERT INTO alergia_animal (cpf_tutor, nome_animal, alergia) VALUES
('22222222201', 'Simba', 'Pulgas'),
('22222222202', 'Thor',  'Poeira'),
('22222222202', 'Thor',  'Frango');
-- Mel (Ana), Mel (Carla), Pantera e Fred: 0 alergias (sem linhas)

INSERT INTO consulta (cpf_tutor, nome_animal, data, hora, peso, diagnostico, cpf_veterinario) VALUES
('22222222201', 'Mel',     '2026-03-02', '09:00:00', 8.40,  'Consulta de rotina',          '33333333301'),
('22222222201', 'Mel',     '2026-06-15', '10:00:00', 8.60,  'Dermatite alérgica',          '33333333303'),
('22222222201', 'Simba',   '2026-03-02', '09:30:00', 4.20,  'Vacinação anual',             '33333333301'),
('22222222202', 'Thor',    '2026-04-10', '14:00:00', 32.00, 'Fratura leve na pata dianteira','33333333302'),
('22222222202', 'Thor',    '2026-07-01', '08:30:00', 33.10, 'Retorno pós-cirúrgico',       '33333333304'),
('22222222203', 'Mel',     '2026-05-05', '11:00:00', 3.90,  'Alergia de pele',             '33333333303'),
('22222222203', 'Pantera', '2026-05-05', '11:30:00', 40.20, 'Check-up anual',              '33333333301'),
('22222222204', 'Fred',    '2026-06-20', '16:00:00', 0.09,  'Bicagem de penas',            '33333333302');

INSERT INTO prescricao (cpf_tutor, nome_animal, data, hora, nome_comercial, dosagem, duracao_dias) VALUES
('22222222201', 'Mel',     '2026-03-02', '09:00:00', 'Vetmedin',      '1 comprimido 12/12h',    30),
('22222222201', 'Mel',     '2026-03-02', '09:00:00', 'Flancox',       '1 dose única',            1),
('22222222201', 'Mel',     '2026-06-15', '10:00:00', 'Meloxivet',     '0,5ml 1x/dia',            7),
('22222222201', 'Simba',   '2026-03-02', '09:30:00', 'Simparic',      '1 comprimido mensal',    30),
('22222222202', 'Thor',    '2026-04-10', '14:00:00', 'Meloxivet',     '1ml 12/12h',             10),
('22222222202', 'Thor',    '2026-04-10', '14:00:00', 'Amoxilina Pet', '250mg 8/8h',             14),
('22222222202', 'Thor',    '2026-07-01', '08:30:00', 'Meloxivet',     '1ml 1x/dia',              5),
('22222222203', 'Mel',     '2026-05-05', '11:00:00', 'Simparic',      '1 comprimido',           30),
('22222222203', 'Pantera', '2026-05-05', '11:30:00', 'Flancox',       '1 dose única',            1),
('22222222204', 'Fred',    '2026-06-20', '16:00:00', 'Amoxilina Pet', '50mg 12/12h',             7);
