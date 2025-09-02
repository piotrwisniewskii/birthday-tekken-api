package com.example.birthday_tekken_api.messaging;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.List;

import static com.example.birthday_tekken_api.messaging.RabbitConfig.EXCHANGE;

@Component
public class TournamentEventPublisher {
    private final RabbitTemplate rabbit;

    public TournamentEventPublisher(RabbitTemplate rabbit) {
        this.rabbit = rabbit;
    }

    public void publish(String type, String tournamentId, Integer round, List<String> payload) {
        TournamentEvent event = new TournamentEvent(type, tournamentId, round, payload, Instant.now());
        rabbit.convertAndSend(EXCHANGE, "tournament." + type, event);
    }
}
