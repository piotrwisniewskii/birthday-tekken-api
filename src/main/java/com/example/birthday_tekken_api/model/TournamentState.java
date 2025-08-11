package com.example.birthday_tekken_api.model;

import java.util.ArrayList;
import java.util.List;

public class TournamentState {
    private List<String> currentPlayers = new ArrayList<>();
    private List<Match> history = new ArrayList<>();
    private List<Match> currentMatches = new ArrayList<>();
    private int round = 0;
    private boolean finished = false;
    private String winner;
    private String runnerUp;
    private String thirdPlace;
    private Match thirdPlaceMatch;
    private boolean thirdPlaceMatchRequired = false;

    public List<String> getCurrentPlayers() {
        return currentPlayers;
    }

    public void setCurrentPlayers(List<String> currentPlayers) {
        this.currentPlayers = currentPlayers;
    }

    public List<Match> getHistory() {
        return history;
    }

    public void setHistory(List<Match> history) {
        this.history = history;
    }

    public List<Match> getCurrentMatches() {
        return currentMatches;
    }

    public void setCurrentMatches(List<Match> currentMatches) {
        this.currentMatches = currentMatches;
    }

    public int getRound() {
        return round;
    }

    public void setRound(int round) {
        this.round = round;
    }

    public void incrementRound() {
        this.round++;
    }

    public boolean isFinished() {
        return finished;
    }

    public void setFinished(boolean finished) {
        this.finished = finished;
    }

    public String getWinner() {
        return winner;
    }

    public void setWinner(String winner) {
        this.winner = winner;
    }

    public String getRunnerUp() {
        return runnerUp;
    }

    public void setRunnerUp(String runnerUp) {
        this.runnerUp = runnerUp;
    }

    public String getThirdPlace() {
        return thirdPlace;
    }

    public void setThirdPlace(String thirdPlace) {
        this.thirdPlace = thirdPlace;
    }

    public Match getThirdPlaceMatch() {
        return thirdPlaceMatch;
    }

    public void setThirdPlaceMatch(Match thirdPlaceMatch) {
        this.thirdPlaceMatch = thirdPlaceMatch;
    }

    public boolean isThirdPlaceMatchRequired() {
        return thirdPlaceMatchRequired;
    }

    public void setThirdPlaceMatchRequired(boolean thirdPlaceMatchRequired) {
        this.thirdPlaceMatchRequired = thirdPlaceMatchRequired;
    }
}