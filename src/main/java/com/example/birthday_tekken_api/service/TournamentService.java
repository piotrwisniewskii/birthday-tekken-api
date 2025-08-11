package com.example.birthday_tekken_api.service;

import com.example.birthday_tekken_api.model.Match;
import com.example.birthday_tekken_api.model.TournamentState;
import org.springframework.stereotype.Service;
import java.util.*;

@Service
public class TournamentService {
	private final TournamentState state = new TournamentState();
	private final MatchRepository matchRepository;

    public TournamentService(MatchRepository matchRepository) {
        this.matchRepository = matchRepository;
    }

    public void start(List<String> players) {
		if (players.size() < 2) {
			throw new IllegalArgumentException("Tournament requires at least 2 players");
		}
		state.getHistory().clear();
		state.setCurrentPlayers(new ArrayList<>(players));
		state.setRound(1);
		List<Match> matches = generateMatches();
		state.setCurrentMatches(matches);
		state.setFinished(false);
		state.setWinner(null);
		state.setRunnerUp(null);
		state.setThirdPlace(null);
		state.setThirdPlaceMatchRequired(false);
		state.setThirdPlaceMatch(null);
	}

	public List<Match> generateMatches() {
		List<String> players = new ArrayList<>(state.getCurrentPlayers());
		// Zapewnij lepszą losowość przez utworzenie nowego obiektu Random na każde shuffle
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

	public void submitResults(List<Match> results) {
		List<String> nextRound = new ArrayList<>();
		List<Match> submittedMatches = new ArrayList<>();

		for (Match match : results) {
			if (match.isByeMatch()) {
				nextRound.add(match.getPlayer1());
				// Byes też powinny być zapisane w historii:
				state.getHistory().add(match);
				continue;
			}
			if (match.getWinner() == null ||
					(!match.getPlayer1().equals(match.getWinner()) &&
							!match.getPlayer2().equals(match.getWinner()))) {
				throw new IllegalArgumentException("Invalid winner for match");
			}

			state.getHistory().add(match);
			submittedMatches.add(match);
			nextRound.add(match.getWinner());
		}

		state.setCurrentPlayers(nextRound);

		if (nextRound.size() == 1) {
			state.setFinished(true);
			state.setWinner(nextRound.get(0));
			// Find the final match (non-bye), last from this submission. Runner-up is the loser.
			Match finalMatch = null;
			for (int i = submittedMatches.size() - 1; i >= 0; i--) {
				if (!submittedMatches.get(i).isByeMatch()) {
					finalMatch = submittedMatches.get(i);
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

			// Third-place match: znajdź przegranych z półfinałów (jeśli startowało co najmniej 4)
			if (state.getHistory().size() >= 3) {
				List<Match> history = state.getHistory();
				List<String> semifinalLosers = new ArrayList<>();
				// Skanuj od końca do przodu aż 2 przegranych
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
	}

	public void submitThirdPlaceResult(String winner) {
		if (!state.isThirdPlaceMatchRequired()) {
			throw new IllegalStateException("Third place match is not available");
		}
		Match thirdPlaceMatch = state.getThirdPlaceMatch();
		if (!thirdPlaceMatch.getPlayer1().equals(winner) &&
				!thirdPlaceMatch.getPlayer2().equals(winner)) {
			throw new IllegalArgumentException("Invalid winner for third place match");
		}

		thirdPlaceMatch.setWinner(winner);
		// dodaj do historii trzeci mecz o miejsce:
		state.getHistory().add(thirdPlaceMatch);
		state.setThirdPlace(winner);
		state.setThirdPlaceMatchRequired(false);
	}

	public TournamentState getState() {
		return state;
	}
}
