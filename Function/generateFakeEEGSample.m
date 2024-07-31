function eegSample = generateFakeEEGSample(numChannels, amplitude, noise_level)
    % 基本的な正弦波を生成
    t = linspace(0, 2*pi, numChannels);
    basicWave = sin(t) + sin(2*t) + sin(3*t);
    
    % 振幅を調整
    scaledWave = basicWave * amplitude;
    
    % ノイズを追加
    noise = randn(1, numChannels) * noise_level;
    
    % 最終的な擬似EEGサンプル
    eegSample = scaledWave + noise;
end