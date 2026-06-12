package com.fisherman.safety.controller;

import com.fisherman.safety.model.ChatMessage;
import com.fisherman.safety.model.User;
import com.fisherman.safety.repository.ChatMessageRepository;
import com.fisherman.safety.repository.UserRepository;
import com.fisherman.safety.exception.ResourceNotFoundException;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/chat")
@Tag(name = "Chat Messaging", description = "Endpoints for user-to-user chat messaging and automatically sending coordinates on SOS.")
public class ChatController {

    @Autowired
    private ChatMessageRepository chatMessageRepository;

    @Autowired
    private UserRepository userRepository;

    private String getAuthenticatedMobile() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    private User getAuthenticatedUser() {
        String mobile = getAuthenticatedMobile();
        return userRepository.findByMobileNumber(mobile)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + mobile));
    }

    @PostMapping("/send")
    @Operation(summary = "Send chat message", description = "Sends a chat message to another user.")
    public ResponseEntity<?> sendMessage(@RequestBody Map<String, Object> payload) {
        User sender = getAuthenticatedUser();
        Long recipientId = Long.valueOf(payload.get("recipientId").toString());
        User recipient = userRepository.findById(recipientId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipient not found with id: " + recipientId));

        String messageText = (String) payload.get("message");
        Double lat = payload.containsKey("latitude") && payload.get("latitude") != null ? Double.valueOf(payload.get("latitude").toString()) : null;
        Double lon = payload.containsKey("longitude") && payload.get("longitude") != null ? Double.valueOf(payload.get("longitude").toString()) : null;
        boolean isSos = payload.containsKey("isSos") && payload.get("isSos") != null && (boolean) payload.get("isSos");

        ChatMessage message = ChatMessage.builder()
                .sender(sender)
                .recipient(recipient)
                .message(messageText)
                .latitude(lat)
                .longitude(lon)
                .isSos(isSos)
                .build();

        ChatMessage saved = chatMessageRepository.save(message);
        return new ResponseEntity<>(mapToDto(saved), HttpStatus.CREATED);
    }

    @GetMapping("/history/{recipientId}")
    @Operation(summary = "Get chat history", description = "Fetches the chat message history between the authenticated user and another user.")
    public ResponseEntity<?> getChatHistory(@PathVariable Long recipientId) {
        User sender = getAuthenticatedUser();
        List<ChatMessage> messages = chatMessageRepository.findChatHistory(sender.getId(), recipientId);
        List<Map<String, Object>> response = messages.stream().map(this::mapToDto).collect(Collectors.toList());
        return ResponseEntity.ok(response);
    }

    private Map<String, Object> mapToDto(ChatMessage msg) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", msg.getId());
        map.put("senderId", msg.getSender().getId());
        map.put("senderName", msg.getSender().getFullName());
        map.put("recipientId", msg.getRecipient().getId());
        map.put("recipientName", msg.getRecipient().getFullName());
        map.put("message", msg.getMessage());
        map.put("latitude", msg.getLatitude());
        map.put("longitude", msg.getLongitude());
        map.put("isSos", msg.isSos());
        map.put("createdAt", msg.getCreatedAt().format(DateTimeFormatter.ISO_DATE_TIME));
        return map;
    }
}
