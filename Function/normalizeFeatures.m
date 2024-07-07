function [normalized_features, feature_mean, feature_std] = normalizeFeatures(features)
    feature_mean = mean(features);
    feature_std = std(features);
    normalized_features = (features - feature_mean) ./ feature_std;
end


