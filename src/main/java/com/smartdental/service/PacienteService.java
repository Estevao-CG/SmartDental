package com.smartdental.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.smartdental.entity.Paciente;
import com.smartdental.repository.PacienteRepository;

@Service
public class PacienteService {

    @Autowired
    private PacienteRepository pacienteRepository;

    public Paciente salvar(Paciente paciente) {
        // valida os campos obrigatorios
        if (paciente.getNome() == null || paciente.getNome().equals("")) {
            throw new RuntimeException("O nome e obrigatorio");
        }
        if (paciente.getCpf() == null || paciente.getCpf().equals("")) {
            throw new RuntimeException("O CPF e obrigatorio");
        }
        paciente.setAtivo(true);
        return pacienteRepository.save(paciente);
    }

    public List<Paciente> listar() {
        return pacienteRepository.findAll();
    }

    public Paciente buscar(Long id) {
        Paciente p = pacienteRepository.findById(id).orElse(null);
        if (p == null) {
            throw new RuntimeException("Paciente nao encontrado");
        }
        return p;
    }

    public Paciente editar(Long id, Paciente novo) {
        Paciente p = buscar(id);
        p.setNome(novo.getNome());
        p.setCpf(novo.getCpf());
        p.setTelefone(novo.getTelefone());
        return pacienteRepository.save(p);
    }

    // nao apaga do banco, so deixa inativo
    public void inativar(Long id) {
        Paciente p = buscar(id);
        p.setAtivo(false);
        pacienteRepository.save(p);
    }
}
