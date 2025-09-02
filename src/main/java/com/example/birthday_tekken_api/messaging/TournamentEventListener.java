package com.example.birthday_tekken_api.messaging;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import static com.example.birthday_tekken_api.messaging.RabbitConfig.QUEUE;

@Component
public class TournamentEventListener {
    private static final Logger log = LoggerFactory.getLogger(TournamentEventListener.class);

    @RabbitListener(queues = QUEUE)
    public void handle(TournamentEvent event) {
        log.info("Received event: {}", event);
    }
}
