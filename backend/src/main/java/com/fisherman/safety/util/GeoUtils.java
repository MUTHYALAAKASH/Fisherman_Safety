package com.fisherman.safety.util;

public class GeoUtils {

    private static final double EARTH_RADIUS_KM = 6371.0;

    /**
     * Calculates the distance in kilometers between two GPS points using the Haversine formula.
     */
    public static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return EARTH_RADIUS_KM * c;
    }

    /**
     * Converts speed in kilometers per hour or meters per second to Knots.
     * Speed is typically recorded by GPS in m/s or km/h. If m/s, multiply by 1.94384. If km/h, multiply by 0.539957.
     */
    public static double kmhToKnots(double speedKmh) {
        return speedKmh * 0.539957;
    }
}
