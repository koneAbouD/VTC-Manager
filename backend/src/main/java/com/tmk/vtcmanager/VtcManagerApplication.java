package com.tmk.vtcmanager;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class VtcManagerApplication {

    public static void main(String[] args) {
        SpringApplication.run(VtcManagerApplication.class, args);
    }
}
