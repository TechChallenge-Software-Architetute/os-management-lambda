package com.os.workshop.auth;

import com.amazonaws.services.lambda.runtime.Context;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Emits one structured (JSON) log line per event to CloudWatch Logs, always carrying the
 * Lambda request id so a request can be correlated across the API Gateway access log,
 * the authorizer and the issuer.
 */
final class JsonLog {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private JsonLog() {
    }

    static void info(Context context, String event, Map<String, Object> fields) {
        write(context, "INFO", event, fields);
    }

    static void warn(Context context, String event, Map<String, Object> fields) {
        write(context, "WARN", event, fields);
    }

    /** Masks a CPF/CNPJ so it never lands in the logs in full: {@code 52998224725 -> 529******25}. */
    static String maskDocument(String digits) {
        if (digits == null || digits.length() < 5) {
            return "***";
        }
        return digits.substring(0, 3)
                + "*".repeat(digits.length() - 5)
                + digits.substring(digits.length() - 2);
    }

    private static void write(Context context, String level, String event, Map<String, Object> fields) {
        Map<String, Object> line = new LinkedHashMap<>();
        line.put("level", level);
        line.put("event", event);
        if (context != null) {
            line.put("requestId", context.getAwsRequestId());
            line.put("function", context.getFunctionName());
        }
        if (fields != null) {
            line.putAll(fields);
        }
        try {
            String json = MAPPER.writeValueAsString(line);
            if (context != null) {
                context.getLogger().log(json);
            } else {
                System.out.println(json);
            }
        } catch (Exception e) {
            System.out.println("{\"level\":\"WARN\",\"event\":\"log_serialization_failed\"}");
        }
    }
}
