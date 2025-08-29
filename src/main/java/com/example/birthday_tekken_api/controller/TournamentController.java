package com.example.birthday_tekken_api.controller;

import com.example.birthday_tekken_api.model.Match;
import com.example.birthday_tekken_api.model.TournamentState;
import com.example.birthday_tekken_api.service.TournamentService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tournament")
@CrossOrigin(origins = "*")
public class TournamentController {

    private final TournamentService tournamentService;

    public TournamentController(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    @PostMapping("/start")
    public ResponseEntity<TournamentState> start(@RequestBody List<String> players) {
        tournamentService.start(players);
        return ResponseEntity.ok(tournamentService.getState());
    }

    @GetMapping("/state")
    public ResponseEntity<TournamentState> getState() {
        return ResponseEntity.ok(tournamentService.getState());
    }

    @PostMapping("/submit-results")
    public ResponseEntity<TournamentState> submitResults(@RequestBody List<Match> results) {
        tournamentService.submitResults(results);
        return ResponseEntity.ok(tournamentService.getState());
    }

    @PostMapping("/submit-third-place")
    public ResponseEntity<TournamentState> submitThirdPlace(@RequestParam String winner) {
        tournamentService.submitThirdPlaceResult(winner);
        return ResponseEntity.ok(tournamentService.getState());
    }

    @GetMapping("/matches/all")
    public ResponseEntity<List<Match>> getAllMatches() {
        return ResponseEntity.ok(tournamentService.findAllMatches());
    }

    @DeleteMapping("/matches")
    public ResponseEntity<Void> deleteAllMatches() {
        tournamentService.deleteAllMatches();
        return ResponseEntity.noContent().build(); 
    }

    @PostMapping("/matches/delete-all") // na potrzeby guzika w matches ( html nie obsługuje endpointa delete - w przyszłosci zmienić .html na thymeleaf"
    public ResponseEntity<Void> deleteAllMatchesPost() {
        tournamentService.deleteAllMatches();
        return ResponseEntity.noContent().build();
    }
z

}
