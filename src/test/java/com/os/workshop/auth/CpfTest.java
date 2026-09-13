package com.os.workshop.auth;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CpfTest {

    @Test
    void acceptsValidCpfAndNormalizesDigits() {
        Cpf cpf = new Cpf("529.982.247-25");
        assertThat(cpf.getValue()).isEqualTo("52998224725");
        assertThat(cpf.formatted()).isEqualTo("529.982.247-25");
    }

    @Test
    void rejectsNull() {
        assertThatThrownBy(() -> new Cpf(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsWrongLength() {
        assertThatThrownBy(() -> new Cpf("123"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsAllIdenticalDigits() {
        assertThatThrownBy(() -> new Cpf("11111111111"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsWrongCheckDigit() {
        assertThatThrownBy(() -> new Cpf("52998224724"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
