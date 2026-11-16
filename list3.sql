-- ATIVIDADE_1

CREATE OR REPLACE VIEW vw_prontuario AS
    SELECT
        t.cpf           AS cpf_tutor,
        t.nome          AS nome_tutor,
        a.nome          AS nome_animal,
        a.especie       AS especie_animal,
        c.data			AS data_consulta,
        c.hora			AS hora_consulta,
        c.peso			AS peso_consulta,
        f.nome			AS nome_veterinario
    FROM
    	consulta c
    JOIN funcionario f ON c.cpf_veterinario = f.cpf
    JOIN tutor t ON c.cpf_tutor = t.cpf
    JOIN animal a ON t.cpf = a.cpf_tutor;

SELECT * FROM vw_prontuario ORDER BY nome_tutor;

-- ATIVIDADE_2

CREATE OR REPLACE VIEW vw_contato_tutor AS
	SELECT
		t.nome 													AS nome_tutor,
		t.end_cidade 											AS cidade_tutor,
		STRING_AGG(tt.telefone, ', ' ORDER BY tt.telefone)		AS telefones_tutor
	FROM
		tutor t
	LEFT JOIN telefone_tutor tt ON tt.cpf_tutor = t.cpf
	GROUP BY t.cpf, t.nome, t.end_cidade;

SELECT * FROM vw_contato_tutor;


-- ATIVIDADE_3

CREATE OR REPLACE VIEW vw_animal_ficha AS
	SELECT
		t.nome															AS nome_tutor,
		a.nome															AS nome_animal,
		a.especie														AS especie_animal,
		a.raca															AS raca_animal,
		EXTRACT(YEAR FROM AGE(current_date, a.data_nascimento))::int 	AS idade_animal,
		COUNT(aa.alergia)												AS alergia_animal
	FROM
		animal a
	INNER JOIN tutor t ON a.cpf_tutor = t.cpf
	LEFT JOIN alergia_animal aa
	       ON aa.cpf_tutor = a.cpf_tutor
	      AND aa.nome_animal = a.nome
	GROUP BY a.cpf_tutor, a.nome, t.nome, a.especie, a.raca, a.data_nascimento;

COMMENT ON VIEW vw_animal_ficha IS
'A idade nunca fica desatualizada porque a view não armazena dados: a cada SELECT a consulta é reexecutada e current_date é avaliado naquele momento, recalculando a idade a partir de data_nascimento (que não muda). Uma coluna idade gravada na tabela ficaria errada no aniversário do animal e precisaria de UPDATE periódico.';

SELECT * FROM vw_animal_ficha;

-- ATIVIDADE_6

CREATE OR REPLACE VIEW vw_animais_retorno AS
	SELECT
		nome_tutor									AS tutor,
		nome_animal									AS animal,
		COUNT(*) 									AS quantidade_consultas,
		MIN(data_consulta)							AS data_consulta_inicial,
		MAX(data_consulta)							AS data_consulta_final,
		MAX(data_consulta) - MIN(data_consulta) 	AS dias_entre
	FROM
		vw_prontuario
	GROUP BY
		nome_tutor,
		nome_animal
	HAVING COUNT(*) >= 2;

SELECT * FROM vw_animais_retorno;

-- ATIVIDADE_7

CREATE OR REPLACE VIEW vw_medicamento_economico AS
	SELECT
		m.nome_comercial		AS nome_comercial,
		m.principio_ativo		AS principio_ativo,
		m.preco					AS preco_medicamentos
	FROM
		medicamento m
	WHERE m.preco < 50;

UPDATE vw_medicamento_economico
SET preco_medicamentos = preco_medicamentos * 1.1;

SELECT * FROM vw_medicamento_economico;

INSERT INTO vw_medicamento_economico (nome_comercial, principio_ativo, preco_medicamentos)
VALUES ('Apoquel', 'Oclacitinib', 189);

SELECT * from vw_medicamento_economico;

-- Na View o medicamento Oclacitinib não será exibido, pois o filtro de where m.preco < 50 é sempre acionado, e o medicamento é mais caro que 50 reais.
-- Na tabela aparece, pois essa é uma view de uma única tabela somente, logo o insert é resolvido e os dados inseridos.
