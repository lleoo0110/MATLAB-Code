function normalized_features = normalizeRealtimeFeatures(features, feature_mean, feature_std)
    normalized_features = (features - feature_mean) ./ feature_std;
end