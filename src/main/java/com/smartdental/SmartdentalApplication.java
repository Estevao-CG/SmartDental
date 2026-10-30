package com.smartdental;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SmartdentalApplication {

    public static void main(String[] args) {
        SpringApplication.run(SmartdentalApplication.class, args);
        System.out.println("SmartDental iniciou!");
    }
}
