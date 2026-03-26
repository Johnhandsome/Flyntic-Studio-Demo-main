namespace FlynticStudio.Data.DTOs;

/// <summary>
/// DTO for placing a component on the grid
/// </summary>
public class PlaceComponentRequest
{
    public string ComponentId { get; set; } = string.Empty;
    public int GridX { get; set; }
    public int GridY { get; set; }
}

/// <summary>
/// DTO for updating a placed component
/// </summary>
public class UpdatePlacedComponentRequest
{
    public string InstanceId { get; set; } = string.Empty;
    public int? GridX { get; set; }
    public int? GridY { get; set; }
    public int? Rotation { get; set; }
    public bool? IsSelected { get; set; }
}

/// <summary>
/// DTO for moving a placed component
/// </summary>
public class MoveComponentRequest
{
    public string InstanceId { get; set; } = string.Empty;
    public int NewGridX { get; set; }
    public int NewGridY { get; set; }
}

/// <summary>
/// DTO for removing a component
/// </summary>
public class RemoveComponentRequest
{
    public string InstanceId { get; set; } = string.Empty;
}

/// <summary>
/// Generic API response
/// </summary>
public class ApiResponse<T>
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public T? Data { get; set; }
    public List<string> Errors { get; set; } = new();
}

/// <summary>
/// DTO for component information
/// </summary>
public class ComponentDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public double Weight { get; set; }
    public double Thrust { get; set; }
    public double PowerConsumption { get; set; }
    public double Capacity { get; set; }
    public double Voltage { get; set; }
    public string IconClass { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public int Width { get; set; }
    public int Height { get; set; }
}

/// <summary>
/// DTO for placed component information
/// </summary>
public class PlacedComponentDto
{
    public string InstanceId { get; set; } = string.Empty;
    public string ComponentId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public int GridX { get; set; }
    public int GridY { get; set; }
    public int Width { get; set; }
    public int Height { get; set; }
    public int Rotation { get; set; }
    public bool IsSelected { get; set; }
    public string IconClass { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
}

/// <summary>
/// DTO for hierarchy node
/// </summary>
public class HierarchyNodeDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsExpanded { get; set; }
    public bool IsLayer { get; set; }
    public string? ParentId { get; set; }
    public string? ComponentInstanceId { get; set; }
    public List<HierarchyNodeDto> Children { get; set; } = new();
}

/// <summary>
/// DTO for drone configuration
/// </summary>
public class ConfigurationDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public List<PlacedComponentDto> PlacedComponents { get; set; } = new();
    public HierarchyNodeDto? Hierarchy { get; set; }
    public string SimulationState { get; set; } = string.Empty;
    public PerformanceDto? Performance { get; set; }
}

/// <summary>
/// DTO for performance data
/// </summary>
public class PerformanceDto
{
    public double TotalWeight { get; set; }
    public double TotalThrust { get; set; }
    public double ThrustToWeightRatio { get; set; }
    public double EstimatedFlightTime { get; set; }
    public double TotalPowerConsumption { get; set; }
    public string PerformanceRating { get; set; } = string.Empty;
    public bool IsValid { get; set; }
    public List<string> ValidationErrors { get; set; } = new();
}

/// <summary>
/// DTO for simulation result
/// </summary>
public class SimulationResultDto
{
    public bool Success { get; set; }
    public string State { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public List<string> Errors { get; set; } = new();
}

/// <summary>
/// Request to add a new layer
/// </summary>
public class AddLayerRequest
{
    public string Name { get; set; } = string.Empty;
    public string? ParentId { get; set; }
}

/// <summary>
/// Request to move a node to a new parent
/// </summary>
public class MoveNodeRequest
{
    public string NodeId { get; set; } = string.Empty;
    public string NewParentId { get; set; } = string.Empty;
}
