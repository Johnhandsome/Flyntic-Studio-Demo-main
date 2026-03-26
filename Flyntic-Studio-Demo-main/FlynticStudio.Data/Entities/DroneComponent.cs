using FlynticStudio.Data.Enums;

namespace FlynticStudio.Data.Entities;

/// <summary>
/// Represents a drone component that can be placed on the assembly grid
/// </summary>
public class DroneComponent
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = string.Empty;
    public ComponentType Type { get; set; }
    public string Description { get; set; } = string.Empty;
    
    // Physical properties
    public double Weight { get; set; } // in grams
    public double Thrust { get; set; } // in kg (for motors)
    public double PowerConsumption { get; set; } // in watts
    public double Capacity { get; set; } // in mAh (for batteries)
    public double Voltage { get; set; } // in volts
    
    // Visual properties
    public string IconClass { get; set; } = string.Empty;
    public string Color { get; set; } = "#666666";
    public int Width { get; set; } = 1; // Grid units
    public int Height { get; set; } = 1; // Grid units
    
    // Position on grid (when placed)
    public int? GridX { get; set; }
    public int? GridY { get; set; }
    
    // Metadata
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsPlaced { get; set; } = false;
}
