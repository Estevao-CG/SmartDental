package com.smartdental.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.smartdental.entity.Atendimento;
import com.smartdental.repository.AtendimentoRepository;
import com.smartdental.repository.PacienteRepository;
import com.smartdental.repository.ProfissionalRepository;

@Service
public class AtendimentoService {

    @Autowired
    private AtendimentoRepository atendimentoRepository;

    @Autowired
    private PacienteRepository pacienteRepository;

    @Autowired
    private ProfissionalRepository profissionalRepository;

    public Atendimento salvar(Atendimento atendimento) {
        if (atendimento.getPacienteId() == null || !pacienteRepository.existsById(atendimento.getPacienteId())) {
            throw new RuntimeException("Paciente invalido");
        }
        if (atendimento.getProfissionalId() == null || !profissionalRepository.existsById(atendimento.getProfissionalId())) {
            throw new RuntimeException("Profissional invalido");
        }
        if (atendimento.getDescricao() == null || atendimento.getDescricao().equals("")) {
            throw new RuntimeException("Precisa escrever a descricao do atendimento");
        }

        // se nao mandou a data usa a de agora
        if (atendimento.getData() == null) {
            atendimento.setData(LocalDateTime.now());
        }
        return atendimentoRepository.save(atendimento);
    }

    // historico do paciente
    public List<Atendimento> historico(Long pacienteId) {
        return atendimentoRepository.findByPacienteId(pacienteId);
    }
}
