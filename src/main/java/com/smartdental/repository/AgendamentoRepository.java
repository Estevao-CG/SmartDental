package com.smartdental.repository;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.smartdental.entity.Agendamento;

public interface AgendamentoRepository extends JpaRepository<Agendamento, Long> {

    // usado para ver se o profissional ja tem consulta nesse horario
    List<Agendamento> findByProfissionalIdAndDataHoraAndSituacao(Long profissionalId, LocalDateTime dataHora, String situacao);

    List<Agendamento> findByProfissionalId(Long profissionalId);
}
