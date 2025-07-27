<?php

namespace GrimReaper\Storage;

/**
 * Storage Route representing routing decision results
 */
class StorageRoute
{
    private StorageProvider $provider;
    private StorageRequest $request;
    private array $providerScores;
    private array $optimizationRecommendations;
    private float $routingTime;

    public function __construct(
        StorageProvider $provider,
        StorageRequest $request,
        array $providerScores,
        array $optimizationRecommendations,
        float $routingTime
    ) {
        $this->provider = $provider;
        $this->request = $request;
        $this->providerScores = $providerScores;
        $this->optimizationRecommendations = $optimizationRecommendations;
        $this->routingTime = $routingTime;
    }

    // Getters
    public function getProvider(): StorageProvider
    {
        return $this->provider;
    }

    public function getRequest(): StorageRequest
    {
        return $this->request;
    }

    public function getProviderScores(): array
    {
        return $this->providerScores;
    }

    public function getOptimizationRecommendations(): array
    {
        return $this->optimizationRecommendations;
    }

    public function getRoutingTime(): float
    {
        return $this->routingTime;
    }

    /**
     * Get selected provider score
     */
    public function getSelectedProviderScore(): float
    {
        $providerId = $this->provider->getId();
        return $this->providerScores[$providerId]['total_score'] ?? 0.0;
    }

    /**
     * Get routing decision summary
     */
    public function getRoutingSummary(): array
    {
        return [
            'selected_provider' => $this->provider->getName(),
            'provider_id' => $this->provider->getId(),
            'total_score' => $this->getSelectedProviderScore(),
            'routing_time' => $this->routingTime,
            'recommendations_count' => count($this->optimizationRecommendations),
            'request_id' => $this->request->getId()
        ];
    }
} 