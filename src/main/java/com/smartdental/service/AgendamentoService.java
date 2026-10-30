package com.smartdental.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.smartdental.entity.Agendamento;
import com.smartdental.repository.AgendamentoRepository;
import com.smartdental.repository.PacienteRepository;
import com.smartdental.repository.ProfissionalRepository;

@Service
public class AgendamentoService {

    @Autowired
    private AgendamentoRepository agendamentoRepository;

    @Autowired
    private PacienteRepository pacienteRepository;

    @Autowired
    private ProfissionalRepository profissionalRepository;

    public Agendamento salvar(Agendamento agendamento) {
        // ve se mandou tudo
        if (agendamento.getPacienteId() == null) {
            throw new RuntimeException("Precisa informar o paciente");
        }
        if (agendamento.getProfissionalId() == null) {
            throw new RuntimeException("Precisa informar o profissional");
        }
        if (agendamento.getDataHora() == null) {
            throw new RuntimeException("Precisa informar a data e hora");
        }

        // ve se o paciente e o profissional existem
        if (!pacienteRepository.existsById(agendamento.getPacienteId())) {
            throw new RuntimeException("Paciente nao existe");
        }
        if (!profissionalRepository.existsById(agendamento.getProfissionalId())) {
            throw new RuntimeException("Profissional nao existe");
        }

        // ve se ja tem consulta no mesmo horario (conflito de agenda)
        List<Agendamento> conflitos = agendamentoRepository.findByProfissionalIdAndDataHoraAndSituacao(
                agendamento.getProfissionalId(), agendamento.getDataHora(), "AGENDADO");
        if (conflitos.size() > 0) {
            throw new RuntimeException("O profissional ja tem consulta nesse horario");
        }

        agendamento.setSituacao("AGENDADO");
        return agendamentoRepository.save(agendamento);
    }

    public List<Agendamento> listar() {
        return agendamentoRepository.findAll();
    }

    public List<Agendamento> listarPorProfissional(Long profissionalId) {
        return agendamentoRepository.findByProfissionalId(profissionalId);
    }

    public Agendamento cancelar(Long id) {
        Agendamento a = agendamentoRepository.findById(id).orElse(null);
        if (a == null) {
            throw new RuntimeException("Agendamento nao encontrado");
        }
        a.setSituacao("CANCELADO");
        return agendamentoRepository.save(a);
    }
}
