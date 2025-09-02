package com.example.birthday_tekken_api.messaging;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitConfig {
    public static final String EXCHANGE = "tournament.exchange";
    public static final String QUEUE    = "tournament.events";
    public static final String ROUTING  = "tournament.#";

    @Bean
    public TopicExchange tournamentExchange() {
        return ExchangeBuilder.topicExchange(EXCHANGE).durable(true).build();
    }

    @Bean
    public Queue tournamentQueue() {
        return QueueBuilder.durable(QUEUE).build();
    }

    @Bean
    public Binding tournamentBinding(Queue q, TopicExchange ex) {
        return BindingBuilder.bind(q).to(ex).with(ROUTING);
    }

    @Bean
    public Jackson2JsonMessageConverter messageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory cf, Jackson2JsonMessageConverter conv) {
        RabbitTemplate t = new RabbitTemplate(cf);
        t.setMessageConverter(conv);
        return t;
    }
}
