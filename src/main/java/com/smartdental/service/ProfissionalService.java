package com.smartdental.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.smartdental.entity.Profissional;
import com.smartdental.repository.ProfissionalRepository;

@Service
public class ProfissionalService {

    @Autowired
    private ProfissionalRepository profissionalRepository;

    public Profissional salvar(Profissional profissional) {
        if (profissional.getNome() == null || profissional.getNome().equals("")) {
            throw new RuntimeException("O nome e obrigatorio");
        }
        if (profissional.getCro() == null || profissional.getCro().equals("")) {
            throw new RuntimeException("O CRO e obrigatorio");
        }
        return profissionalRepository.save(profissional);
    }

    public List<Profissional> listar() {
        return profissionalRepository.findAll();
    }

    public Profissional buscar(Long id) {
        Profissional p = profissionalRepository.findById(id).orElse(null);
        if (p == null) {
            throw new RuntimeException("Profissional nao encontrado");
        }
        return p;
    }
}
