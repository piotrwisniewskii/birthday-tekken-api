package com.example.birthday_tekken_api.service;

import com.example.birthday_tekken_api.model.Match;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MatchRepository extends JpaRepository<Match, Long> {
}

