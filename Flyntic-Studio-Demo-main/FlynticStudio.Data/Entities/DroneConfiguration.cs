using FlynticStudio.Data.Enums;

namespace FlynticStudio.Data.Entities;

/// <summary>
/// Represents a complete drone configuration with all its components
/// </summary>
public class DroneConfiguration
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = "New Drone";
    public string Description { get; set; } = string.Empty;
    
    // Components in this configuration
    public List<PlacedComponent> PlacedComponents { get; set; } = new();
    
    // Hierarchy structure
    public HierarchyNode Hierarchy { get; set; } = new();
    
    // Simulation state
    public SimulationState SimulationState { get; set; } = SimulationState.Stopped;
    
    // Metadata
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime ModifiedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Represents a component placed on the assembly grid
/// </summary>
public class PlacedComponent
{
    public string InstanceId { get; set; } = Guid.NewGuid().ToString();
    public string ComponentId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public ComponentType ComponentType { get; set; }
    public int GridX { get; set; }
    public int GridY { get; set; }
    public int Width { get; set; } = 1;
    public int Height { get; set; } = 1;
    public int Rotation { get; set; } = 0; // Degrees
    public bool IsSelected { get; set; } = false;
    
    // Visual properties
    public string IconClass { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    
    // Component properties for calculations
    public double Weight { get; set; }
    public double Thrust { get; set; }
    public double PowerConsumption { get; set; }
    public double Capacity { get; set; }
    public double Voltage { get; set; }
}

/// <summary>
/// Represents a node in the hierarchy tree
/// </summary>
public class HierarchyNode
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = string.Empty;
    public string? ComponentInstanceId { get; set; }
    public string? ParentId { get; set; }
    public bool IsExpanded { get; set; } = true;
    public bool IsLayer { get; set; } = false;
    public List<HierarchyNode> Children { get; set; } = new();
}
