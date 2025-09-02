package com.example.birthday_tekken_api.messaging;

import java.time.Instant;
import java.util.List;

public record TournamentEvent(String type, String tournamentId, Integer round, List<String> payload, Instant at) {}
