package com.smartdental.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.smartdental.entity.Paciente;

public interface PacienteRepository extends JpaRepository<Paciente, Long> {

}
