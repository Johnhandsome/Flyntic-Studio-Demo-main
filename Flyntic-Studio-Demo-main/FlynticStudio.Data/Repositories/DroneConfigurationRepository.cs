using FlynticStudio.Data.Entities;
using FlynticStudio.Data.Enums;

namespace FlynticStudio.Data.Repositories;

/// <summary>
/// In-memory repository for drone configurations
/// </summary>
public class DroneConfigurationRepository : IDroneConfigurationRepository
{
    private DroneConfiguration _currentConfiguration;

    public DroneConfigurationRepository()
    {
        _currentConfiguration = CreateDefaultConfiguration();
    }

    public DroneConfiguration GetCurrentConfiguration()
    {
        return _currentConfiguration;
    }

    public DroneConfiguration SaveConfiguration(DroneConfiguration configuration)
    {
        configuration.ModifiedAt = DateTime.UtcNow;
        _currentConfiguration = configuration;
        return _currentConfiguration;
    }

    public PlacedComponent AddPlacedComponent(PlacedComponent component)
    {
        component.InstanceId = Guid.NewGuid().ToString();
        _currentConfiguration.PlacedComponents.Add(component);
        _currentConfiguration.ModifiedAt = DateTime.UtcNow;
        
        UpdateHierarchyWithComponent(component);
        
        return component;
    }

    public PlacedComponent? UpdatePlacedComponent(PlacedComponent component)
    {
        var existing = _currentConfiguration.PlacedComponents
            .FirstOrDefault(c => c.InstanceId == component.InstanceId);
        
        if (existing == null)
            return null;
        
        existing.GridX = component.GridX;
        existing.GridY = component.GridY;
        existing.Rotation = component.Rotation;
        existing.IsSelected = component.IsSelected;
        _currentConfiguration.ModifiedAt = DateTime.UtcNow;
        
        return existing;
    }

    public bool RemovePlacedComponent(string instanceId)
    {
        var component = _currentConfiguration.PlacedComponents
            .FirstOrDefault(c => c.InstanceId == instanceId);
        
        if (component == null)
            return false;
        
        _currentConfiguration.PlacedComponents.Remove(component);
        _currentConfiguration.ModifiedAt = DateTime.UtcNow;
        
        RemoveFromHierarchy(instanceId);
        
        return true;
    }

    public IEnumerable<PlacedComponent> GetPlacedComponents()
    {
        return _currentConfiguration.PlacedComponents.ToList();
    }

    public void ClearAllComponents()
    {
        _currentConfiguration.PlacedComponents.Clear();
        _currentConfiguration.Hierarchy = CreateDefaultHierarchy();
        _currentConfiguration.SimulationState = SimulationState.Stopped;
        _currentConfiguration.ModifiedAt = DateTime.UtcNow;
    }

    public HierarchyNode GetHierarchy()
    {
        return _currentConfiguration.Hierarchy;
    }

    public HierarchyNode UpdateHierarchy(HierarchyNode hierarchy)
    {
        _currentConfiguration.Hierarchy = hierarchy;
        _currentConfiguration.ModifiedAt = DateTime.UtcNow;
        return hierarchy;
    }

    private DroneConfiguration CreateDefaultConfiguration()
    {
        return new DroneConfiguration
        {
            Id = Guid.NewGuid().ToString(),
            Name = "New Drone Project",
            Description = "A new drone assembly project",
            Hierarchy = CreateDefaultHierarchy(),
            PlacedComponents = new List<PlacedComponent>(),
            SimulationState = SimulationState.Stopped
        };
    }

    private HierarchyNode CreateDefaultHierarchy()
    {
        return new HierarchyNode
        {
            Id = "root",
            Name = "Drone",
            IsExpanded = true,
            Children = new List<HierarchyNode>()
        };
    }

    private void UpdateHierarchyWithComponent(PlacedComponent component)
    {
        var newNode = new HierarchyNode
        {
            Id = component.InstanceId,
            Name = component.Name,
            ComponentInstanceId = component.InstanceId,
            IsExpanded = false
        };
        
        _currentConfiguration.Hierarchy.Children.Add(newNode);
    }

    private void RemoveFromHierarchy(string instanceId)
    {
        var node = _currentConfiguration.Hierarchy.Children
            .FirstOrDefault(n => n.ComponentInstanceId == instanceId);
        
        if (node != null)
        {
            _currentConfiguration.Hierarchy.Children.Remove(node);
        }
    }
}
