// app.js
let currentState = null;
let tournamentNameGlobal = '';

function startTournament() {
  const tournamentName = document.getElementById('tournamentName').value.trim();
  const players = document.getElementById('players').value
    .split('\n')
    .map(p => p.trim())
    .filter(p => p.length > 0);

  if (!tournamentName) { alert('Podaj nazwę turnieju'); return; }
  if (players.length < 2) { alert('Podaj co najmniej 2 graczy'); return; }

  tournamentNameGlobal = tournamentName;

  fetch('/api/tournament/start', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ tournamentName, players })
  })
  .then(async (res) => {
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.message || `Błąd HTTP ${res.status}`);
    }
    return res.json();
  })
  .then(state => {
    currentState = { ...(state || {}) };
    tournamentNameGlobal = currentState.tournamentName || tournamentNameGlobal;
    showTournament();
    updateDisplay();
  })
  .catch(err => { alert(err.message || 'Nie udało się uruchomić turnieju'); });
}

function showTournament() {
  document.getElementById('setup-section').style.display = 'none';
  document.getElementById('tournament-section').style.display = 'block';
}

function updateDisplay() {
  if (!currentState) return;

  document.getElementById('tournament-name').textContent =
    currentState.tournamentName || tournamentNameGlobal || '(bez nazwy)';
  document.getElementById('current-round').textContent = currentState.round;

  const matchesDiv = document.getElementById('matches');
  const matchesCard = document.querySelector('.matches-card');
  matchesDiv.innerHTML = '';

  const statusDiv = document.getElementById('tournament-status');
  const submitButton = document.getElementById('submit-button');

  if (currentState.finished && !currentState.thirdPlaceMatchRequired) {
    statusDiv.innerHTML = `
      <p><strong>Turniej zakończony!</strong></p>
      <p>🏆 Zwycięzca: ${currentState.winner}</p>
      ${currentState.runnerUp ? `<p>🥈 2. miejsce: ${currentState.runnerUp}</p>` : ''}
      ${currentState.thirdPlace ? `<p>🥉 3. miejsce: ${currentState.thirdPlace}</p>` : ''}
    `;
    submitButton.style.display = 'none';
    matchesCard.style.display = 'none';
  } else {
    statusDiv.innerHTML = `<p>Turniej trwa - runda ${currentState.round}</p>`;
    submitButton.style.display = 'block';
    matchesCard.style.display = 'block';
  }

  const matches = currentState.thirdPlaceMatchRequired
    ? [currentState.thirdPlaceMatch]
    : currentState.currentMatches;

  (matches || []).forEach((match, index) => {
    const matchDiv = document.createElement('div');
    matchDiv.className = 'match';

    if (match.byeMatch) {
      matchDiv.className += ' bye-match';
      matchDiv.innerHTML = `<div>${match.player1} awansuje do kolejnej rundy (wolny los)</div>`;
    } else {
      matchDiv.innerHTML = `
        <div class="match-players">
          <div>
            <label>
              <input type="radio" name="match${index}" value="${match.player1}">
              <span class="player">${match.player1}</span>
            </label>
          </div>
          <div>
            <label>
              <input type="radio" name="match${index}" value="${match.player2}">
              <span class="player">${match.player2}</span>
            </label>
          </div>
        </div>
      `;
    }
    matchesDiv.appendChild(matchDiv);
  });

  renderHistory(currentState.history, currentState.thirdPlaceMatch, currentState.thirdPlace);
}

function submitResults() {
  try {
    const matches = currentState.thirdPlaceMatchRequired
      ? [currentState.thirdPlaceMatch]
      : currentState.currentMatches;

    const results = (matches || []).map((match, index) => {
      if (match.byeMatch) {
        return { ...match, winner: match.player1 };
      }
      const winner = document.querySelector(`input[name="match${index}"]:checked`)?.value;
      if (!winner) throw new Error('Wybierz zwycięzcę we wszystkich meczach');
      return { ...match, winner };
    });

    const endpoint = currentState.thirdPlaceMatchRequired
      ? '/api/tournament/submit-third-place?winner=' + encodeURIComponent(results[0].winner)
      : '/api/tournament/submit-results';

    const body = currentState.thirdPlaceMatchRequired ? null : results;

    fetch(endpoint, {
      method: 'POST',
      headers: currentState.thirdPlaceMatchRequired ? {} : {'Content-Type': 'application/json'},
      body: currentState.thirdPlaceMatchRequired ? null : JSON.stringify(body)
    })
    .then(async (res) => {
      if (!res.ok) throw new Error(await res.text() || 'Network response was not ok');
      return res.json();
    })
    .then(state => {
      currentState = { ...(state || {}) };
      tournamentNameGlobal = currentState.tournamentName || tournamentNameGlobal;
      updateDisplay();
    })
    .catch(error => {
      console.error('Error:', error);
      alert(error.message || 'Nie udało się zapisać wyników');
    });
  } catch (error) {
    alert(error.message);
  }
}

function renderHistory(history, thirdPlaceMatch, thirdPlaceWinner) {
  const histSection = document.getElementById('history-section');
  const histContent = document.getElementById('history-content');
  if (!history || history.length === 0) {
    histSection.style.display = 'none';
    return;
  }
  histSection.style.display = 'block';
  histContent.innerHTML = '';

  const rounds = {};
  let thirdPlaceHistory = null;
  history.forEach(match => {
    if (match.round && /third|3\.|trzecie|mecz o 3/i.test(match.round)) {
      thirdPlaceHistory = match; return;
    }
    if (!rounds[match.round]) rounds[match.round] = [];
    rounds[match.round].push(match);
  });

  Object.keys(rounds)
    .sort((a, b) => parseInt(a.replace(/\D/g,''), 10) - parseInt(b.replace(/\D/g,''), 10))
    .forEach(roundName => {
      const roundDiv = document.createElement('div');
      roundDiv.className = 'history-round';
      roundDiv.innerHTML = `<div class="history-round-title">${roundName}</div>`;
      rounds[roundName].forEach(match => {
        const matchEl = document.createElement('div');
        matchEl.className = 'history-match';
        if (match.byeMatch) {
          matchEl.innerHTML = `<span class="bye-match">${match.player1} - wolny los</span>`;
        } else if (match.winner) {
          matchEl.classList.add('winner');
          matchEl.innerHTML = `${match.player1} vs ${match.player2} — <span>Zwycięzca: ${match.winner}</span>`;
        } else {
          matchEl.innerHTML = `${match.player1} vs ${match.player2}`;
        }
        roundDiv.appendChild(matchEl);
      });
      histContent.appendChild(roundDiv);
    });

  if (thirdPlaceHistory) {
    const thirdDiv = document.createElement('div');
    thirdDiv.className = 'history-round';
    thirdDiv.innerHTML = `
      <div class="third-place-title">Mecz o 3. miejsce:</div>
      <div class="history-match${thirdPlaceHistory.winner ? ' winner' : ''}">
        ${thirdPlaceHistory.player1} vs ${thirdPlaceHistory.player2}
        ${thirdPlaceHistory.winner ? `— <span>Zwycięzca: ${thirdPlaceHistory.winner}</span>` : ''}
      </div>`;
    histContent.appendChild(thirdDiv);
  }
}
