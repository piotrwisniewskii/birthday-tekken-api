package com.example.birthday_tekken_api.model;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.OffsetDateTime;

@Entity
@Table(name = "\"match\"")
public class Match {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String player1;
    private String player2;
    private String winner;
    private String round;
    private boolean byeMatch;

    @CreationTimestamp
    private OffsetDateTime matchTime;



    public Match() {}

    public Match(String player1, String player2, String round) {
        this.player1 = player1;
        this.player2 = player2;
        this.round = round;
        this.byeMatch = player2 == null || player2.isEmpty();
    }

    public OffsetDateTime getMatchTime() {
        return matchTime;
    }

    public Long getId() {
        return id;
    }

    public String getPlayer1() {
        return player1;
    }

    public void setPlayer1(String player1) {
        this.player1 = player1;
    }

    public String getPlayer2() {
        return player2;
    }

    public void setPlayer2(String player2) {
        this.player2 = player2;
    }

    public String getWinner() {
        return winner;
    }

    public void setWinner(String winner) {
        this.winner = winner;
    }

    public String getRound() {
        return round;
    }

    public void setRound(String round) {
        this.round = round;
    }

    public boolean isByeMatch() {
        return byeMatch;
    }

    public void setByeMatch(boolean byeMatch) {
        this.byeMatch = byeMatch;
    }
}