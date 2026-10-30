package com.smartdental.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.smartdental.entity.Atendimento;

public interface AtendimentoRepository extends JpaRepository<Atendimento, Long> {

    List<Atendimento> findByPacienteId(Long pacienteId);
}
