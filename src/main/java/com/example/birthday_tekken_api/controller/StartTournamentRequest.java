package com.example.birthday_tekken_api.controller;

import java.util.List;

public record StartTournamentRequest(String tournamentName, List<String> players) {
}
