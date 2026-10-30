package com.smartdental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.smartdental.entity.Atendimento;
import com.smartdental.service.AtendimentoService;

@RestController
@RequestMapping("/atendimentos")
public class AtendimentoController {

    @Autowired
    private AtendimentoService atendimentoService;

    @PostMapping
    public ResponseEntity<?> registrar(@RequestBody Atendimento atendimento) {
        try {
            return ResponseEntity.ok(atendimentoService.salvar(atendimento));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // historico do paciente
    @GetMapping("/paciente/{id}")
    public ResponseEntity<?> historico(@PathVariable Long id) {
        return ResponseEntity.ok(atendimentoService.historico(id));
    }
}
