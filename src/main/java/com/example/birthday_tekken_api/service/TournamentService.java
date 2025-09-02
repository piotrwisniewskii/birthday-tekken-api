package com.example.birthday_tekken_api.service;

import com.example.birthday_tekken_api.messaging.TournamentEventPublisher;
import com.example.birthday_tekken_api.model.Match;
import com.example.birthday_tekken_api.model.TournamentState;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
public class TournamentService {
	private final TournamentState state = new TournamentState();
	private final MatchRepository matchRepository;
    private final TournamentEventPublisher eventPublisher;


    public TournamentService(MatchRepository matchRepository,
                             TournamentEventPublisher eventPublisher) {
        this.matchRepository = matchRepository;
        this.eventPublisher = eventPublisher;
    }


    public void start(List<String> players) {
		List<String> cleaned = players == null ? List.of() :
				players.stream()
						.filter(Objects::nonNull)
						.map(s -> s.replace("\r",""))
						.map(String::trim)
						.filter(s -> !s.isEmpty())
						.distinct()
						.toList();

		if (cleaned.size() < 2) {
			throw new IllegalArgumentException("Podaj co najmniej 2 graczy.");
		}

		state.getHistory().clear();
		state.setCurrentPlayers(new ArrayList<>(cleaned));
		state.setRound(1);
		List<Match> matches = generateMatches();
		state.setCurrentMatches(matches);
		state.setFinished(false);
		state.setWinner(null);
		state.setRunnerUp(null);
		state.setThirdPlace(null);
		state.setThirdPlaceMatchRequired(false);
		state.setThirdPlaceMatch(null);

        // >>> PUBLISH: tournament started
        if (state.getTournamentId() == null || state.getTournamentId().isBlank()) {
            state.setTournamentId(java.util.UUID.randomUUID().toString());
        }
        eventPublisher.publish(
                "started",
                state.getTournamentId(),
                state.getRound(),
                state.getCurrentPlayers()
        );

    }

	public List<Match> generateMatches() {
		List<String> players = new ArrayList<>(state.getCurrentPlayers());
		Collections.shuffle(players, new Random(System.nanoTime()));
		List<Match> matches = new ArrayList<>();

		if (players.size() % 2 != 0) {
			String bye = players.remove(players.size() - 1);
			Match byeMatch = new Match(bye, "", "Round " + state.getRound());
			byeMatch.setWinner(bye);
			matches.add(byeMatch);
		}
		for (int i = 0; i < players.size(); i += 2) {
			matches.add(new Match(players.get(i), players.get(i + 1), "Round " + state.getRound()));
		}
		return matches;
	}

	@Transactional
	public void submitResults(List<Match> results) {
		List<String> nextRound = new ArrayList<>();
		List<Match> toPersist = new ArrayList<>();

		for (Match match : results) {
			// defensywnie: jeśli ktoś wysyła roundLabel zamiast round – nie przeszkadza to w zapisie
			if (match.getWinner() == null && !match.isByeMatch()) {
				throw new IllegalArgumentException("Invalid winner for match");
			}

			state.getHistory().add(match);
			toPersist.add(match);

			if (match.isByeMatch()) {
				nextRound.add(match.getPlayer1());
			} else {
				nextRound.add(match.getWinner());
			}
		}

		if (!toPersist.isEmpty()) {
			matchRepository.saveAll(toPersist);
		}

		state.setCurrentPlayers(nextRound);

		if (nextRound.size() == 1) {
			state.setFinished(true);
			state.setWinner(nextRound.get(0));

			// runner-up z ostatniego „normalnego” meczu z tej rundy
			Match finalMatch = null;
			for (int i = toPersist.size() - 1; i >= 0; i--) {
				if (!toPersist.get(i).isByeMatch()) {
					finalMatch = toPersist.get(i);
					break;
				}
			}
			if (finalMatch != null) {
				String loser = finalMatch.getPlayer1().equals(finalMatch.getWinner())
						? finalMatch.getPlayer2()
						: finalMatch.getPlayer1();
				state.setRunnerUp(loser);
			} else {
				state.setRunnerUp(null);
			}

			// sprawdź, czy potrzebny mecz o 3. miejsce
			if (state.getHistory().size() >= 3) {
				List<Match> history = state.getHistory();
				List<String> semifinalLosers = new ArrayList<>();
				for (int i = history.size() - 2; i >= 0 && semifinalLosers.size() < 2; i--) {
					Match m = history.get(i);
					if (!m.isByeMatch()) {
						String loser = m.getPlayer1().equals(m.getWinner())
								? m.getPlayer2()
								: m.getPlayer1();
						if (!loser.equals(state.getRunnerUp()) && !loser.equals(state.getWinner())) {
							semifinalLosers.add(loser);
						}
					}
				}
				if (semifinalLosers.size() == 2) {
					state.setThirdPlaceMatchRequired(true);
					state.setThirdPlaceMatch(
							new Match(semifinalLosers.get(0), semifinalLosers.get(1), "Third Place Match")
					);
				}
			}
		} else {
			state.incrementRound();
			List<Match> nextMatches = generateMatches();
			state.setCurrentMatches(nextMatches);
		}

        // >>> PUBLISH: round closed or tournament finished
        if (state.isFinished()) {
            java.util.List<String> payload = new java.util.ArrayList<>();
            if (state.getWinner() != null)   payload.add("winner:" + state.getWinner());
            if (state.getRunnerUp() != null) payload.add("runnerUp:" + state.getRunnerUp());
            if (state.getThirdPlace() != null) payload.add("third:" + state.getThirdPlace());
            eventPublisher.publish("finished", state.getTournamentId(), state.getRound(), payload);
        } else {
            eventPublisher.publish("roundClosed", state.getTournamentId(), state.getRound(), state.getCurrentPlayers());
        }

    }

	@Transactional
	public void submitThirdPlaceResult(String winner) {
		if (!state.isThirdPlaceMatchRequired()) {
			throw new IllegalStateException("Third place match is not available");
		}
		Match third = state.getThirdPlaceMatch();
		if (!third.getPlayer1().equals(winner) && !third.getPlayer2().equals(winner)) {
			throw new IllegalArgumentException("Invalid winner for third place match");
		}
		third.setWinner(winner);
		state.getHistory().add(third);
		matchRepository.save(third);
		state.setThirdPlace(winner);
		state.setThirdPlaceMatchRequired(false);
	}

	public TournamentState getState() {
		return state;
	}

	public Match addMatch(Match match) {
		return matchRepository.save(match);
	}

	public List<Match> findAllMatches() {
		return matchRepository.findAll();
	}

	@Transactional
	public void deleteAllMatches() {
		matchRepository.deleteAll();
	}
}
