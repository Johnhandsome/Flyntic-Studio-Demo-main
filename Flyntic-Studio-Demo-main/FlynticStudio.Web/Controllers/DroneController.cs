using Microsoft.AspNetCore.Mvc;
using FlynticStudio.Data.DTOs;
using FlynticStudio.Data.Enums;
using FlynticStudio.Services;

namespace FlynticStudio.Controllers;

/// <summary>
/// API Controller for drone assembly operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class DroneController : ControllerBase
{
    private readonly IDroneAssemblyService _assemblyService;
    private readonly IDroneCalculationService _calculationService;

    public DroneController(
        IDroneAssemblyService assemblyService,
        IDroneCalculationService calculationService)
    {
        _assemblyService = assemblyService;
        _calculationService = calculationService;
    }

    /// <summary>
    /// Get all available components
    /// </summary>
    [HttpGet("components")]
    public ActionResult<IEnumerable<ComponentDto>> GetComponents()
    {
        var components = _assemblyService.GetAvailableComponents();
        return Ok(components);
    }

    /// <summary>
    /// Get components by type
    /// </summary>
    [HttpGet("components/type/{type}")]
    public ActionResult<IEnumerable<ComponentDto>> GetComponentsByType(string type)
    {
        if (!Enum.TryParse<ComponentType>(type, true, out var componentType))
            return BadRequest($"Invalid component type: {type}");
        
        var components = _assemblyService.GetComponentsByType(componentType);
        return Ok(components);
    }

    /// <summary>
    /// Get a specific component by ID
    /// </summary>
    [HttpGet("components/{id}")]
    public ActionResult<ComponentDto> GetComponent(string id)
    {
        var component = _assemblyService.GetComponentById(id);
        if (component == null)
            return NotFound();
        
        return Ok(component);
    }

    /// <summary>
    /// Get current configuration with all placed components
    /// </summary>
    [HttpGet("configuration")]
    public ActionResult<ConfigurationDto> GetConfiguration()
    {
        var config = _assemblyService.GetCurrentConfiguration();
        return Ok(config);
    }

    /// <summary>
    /// Calculate drone performance metrics
    /// </summary>
    [HttpGet("calculate")]
    public ActionResult CalculatePerformance()
    {
        var config = _assemblyService.GetCurrentConfiguration();
        if (config.Performance == null || config.PlacedComponents.Count == 0)
        {
            return Ok(new {
                totalWeight = 0.0,
                totalThrust = 0.0,
                thrustToWeightRatio = 0.0,
                totalPowerConsumption = 0.0,
                batteryCapacity = 0.0,
                estimatedFlightTime = 0.0,
                performanceRating = "N/A",
                flightCapability = "No components",
                isValid = false,
                frameWeight = 0.0,
                motorsWeight = 0.0,
                batteryWeight = 0.0,
                otherComponentsWeight = 0.0,
                errors = new List<string>(),
                warnings = new List<string>()
            });
        }
        
        // Calculate weight breakdown by component type
        double frameWeight = 0, motorsWeight = 0, batteryWeight = 0, otherWeight = 0;
        double batteryCapacity = 0;
        var errors = new List<string>();
        var warnings = new List<string>();
        
        foreach (var comp in config.PlacedComponents)
        {
            var component = _assemblyService.GetComponentById(comp.ComponentId);
            if (component != null)
            {
                switch (comp.Type)
                {
                    case "Frame":
                        frameWeight += component.Weight;
                        break;
                    case "Motor":
                        motorsWeight += component.Weight;
                        break;
                    case "Battery":
                        batteryWeight += component.Weight;
                        batteryCapacity += component.Capacity;
                        break;
                    default:
                        otherWeight += component.Weight;
                        break;
                }
            }
        }
        
        // Determine flight capability
        string flightCapability;
        double ratio = config.Performance.ThrustToWeightRatio;
        if (ratio < 1.0)
        {
            flightCapability = "Cannot fly";
            errors.Add("Thrust-to-weight ratio is below 1:1");
        }
        else if (ratio < 1.5)
        {
            flightCapability = "Marginal";
            warnings.Add("Thrust-to-weight ratio is low (recommended > 2:1)");
        }
        else if (ratio < 2.0)
        {
            flightCapability = "Basic flight";
            warnings.Add("Consider adding more thrust for better performance");
        }
        else
        {
            flightCapability = "Good";
        }
        
        // Check for essential components
        bool hasMotors = config.PlacedComponents.Any(c => c.Type == "Motor");
        bool hasBattery = config.PlacedComponents.Any(c => c.Type == "Battery");
        bool hasFrame = config.PlacedComponents.Any(c => c.Type == "Frame");
        
        if (!hasMotors) errors.Add("No motors placed");
        if (!hasBattery) errors.Add("No battery placed");
        if (!hasFrame) warnings.Add("No frame placed");
        
        return Ok(new {
            totalWeight = config.Performance.TotalWeight,
            totalThrust = config.Performance.TotalThrust,
            thrustToWeightRatio = config.Performance.ThrustToWeightRatio,
            totalPowerConsumption = config.Performance.TotalPowerConsumption,
            batteryCapacity = batteryCapacity,
            estimatedFlightTime = config.Performance.EstimatedFlightTime,
            performanceRating = config.Performance.PerformanceRating,
            flightCapability = flightCapability,
            isValid = config.Performance.IsValid && errors.Count == 0,
            frameWeight = frameWeight,
            motorsWeight = motorsWeight,
            batteryWeight = batteryWeight,
            otherComponentsWeight = otherWeight,
            errors = errors,
            warnings = warnings
        });
    }

    /// <summary>
    /// Place a component on the grid
    /// </summary>
    [HttpPost("place")]
    public ActionResult<PlacedComponentDto> PlaceComponent([FromBody] PlaceComponentRequest request)
    {
        try
        {
            var result = _assemblyService.PlaceComponent(request);
            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { Error = ex.Message });
        }
    }

    /// <summary>
    /// Update a placed component (move, rotate, select)
    /// </summary>
    [HttpPut("update")]
    public ActionResult<PlacedComponentDto> UpdatePlacedComponent([FromBody] UpdatePlacedComponentRequest request)
    {
        var result = _assemblyService.UpdatePlacedComponent(request);
        
        if (result == null)
            return NotFound(new { Error = "Component not found" });
        
        return Ok(result);
    }

    /// <summary>
    /// Remove a placed component
    /// </summary>
    [HttpDelete("remove/{instanceId}")]
    public ActionResult RemoveComponent(string instanceId)
    {
        var success = _assemblyService.RemovePlacedComponent(instanceId);
        
        if (!success)
            return NotFound(new { Error = "Component not found" });
        
        return Ok(new { Success = true, Message = "Component removed" });
    }

    /// <summary>
    /// Clear all placed components
    /// </summary>
    [HttpPost("clear")]
    public ActionResult ClearAllComponents()
    {
        _assemblyService.ClearAllComponents();
        return Ok(new { Success = true, Message = "All components cleared" });
    }

    /// <summary>
    /// Get hierarchy tree
    /// </summary>
    [HttpGet("hierarchy")]
    public ActionResult<HierarchyNodeDto> GetHierarchy()
    {
        var hierarchy = _assemblyService.GetHierarchy();
        return Ok(hierarchy);
    }

    /// <summary>
    /// Add a new layer to hierarchy
    /// </summary>
    [HttpPost("hierarchy/layer")]
    public ActionResult AddLayer([FromBody] AddLayerRequest request)
    {
        try
        {
            var layer = _assemblyService.AddLayer(request.Name, request.ParentId);
            return Ok(layer);
        }
        catch (Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Move a node to a new parent in hierarchy
    /// </summary>
    [HttpPost("hierarchy/move")]
    public ActionResult MoveNode([FromBody] MoveNodeRequest request)
    {
        try
        {
            var success = _assemblyService.MoveNodeToParent(request.NodeId, request.NewParentId);
            if (!success)
                return NotFound(new { error = "Node not found" });
            return Ok(new { success = true });
        }
        catch (Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>
    /// Delete a layer from hierarchy
    /// </summary>
    [HttpDelete("hierarchy/layer/{layerId}")]
    public ActionResult DeleteLayer(string layerId)
    {
        var success = _assemblyService.DeleteLayer(layerId);
        if (!success)
            return NotFound(new { error = "Layer not found" });
        return Ok(new { success = true });
    }

    /// <summary>
    /// Start simulation (play)
    /// </summary>
    [HttpPost("simulation/play")]
    public ActionResult<SimulationResultDto> Play()
    {
        var result = _assemblyService.StartSimulation();
        
        if (!result.Success)
            return BadRequest(result);
        
        return Ok(result);
    }

    /// <summary>
    /// Pause simulation
    /// </summary>
    [HttpPost("simulation/pause")]
    public ActionResult<SimulationResultDto> Pause()
    {
        var result = _assemblyService.PauseSimulation();
        
        if (!result.Success)
            return BadRequest(result);
        
        return Ok(result);
    }

    /// <summary>
    /// Stop simulation
    /// </summary>
    [HttpPost("simulation/stop")]
    public ActionResult<SimulationResultDto> Stop()
    {
        var result = _assemblyService.StopSimulation();
        return Ok(result);
    }

    /// <summary>
    /// Get simulation state
    /// </summary>
    [HttpGet("simulation/state")]
    public ActionResult GetSimulationState()
    {
        var state = _assemblyService.GetSimulationState();
        return Ok(new { State = state.ToString() });
    }
}
