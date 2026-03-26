using FlynticStudio.Data.Entities;

namespace FlynticStudio.Data.Repositories;

/// <summary>
/// Repository interface for managing drone configurations
/// </summary>
public interface IDroneConfigurationRepository
{
    DroneConfiguration GetCurrentConfiguration();
    DroneConfiguration SaveConfiguration(DroneConfiguration configuration);
    PlacedComponent AddPlacedComponent(PlacedComponent component);
    PlacedComponent? UpdatePlacedComponent(PlacedComponent component);
    bool RemovePlacedComponent(string instanceId);
    IEnumerable<PlacedComponent> GetPlacedComponents();
    void ClearAllComponents();
    HierarchyNode GetHierarchy();
    HierarchyNode UpdateHierarchy(HierarchyNode hierarchy);
}
