using FlynticStudio.Data.DTOs;
using FlynticStudio.Data.Entities;
using FlynticStudio.Data.Enums;
using FlynticStudio.Data.Repositories;

namespace FlynticStudio.Services;

/// <summary>
/// Service for managing drone assembly operations
/// </summary>
public class DroneAssemblyService : IDroneAssemblyService
{
    private readonly IComponentRepository _componentRepository;
    private readonly IDroneConfigurationRepository _configurationRepository;
    private readonly IDroneCalculationService _calculationService;

    public DroneAssemblyService(
        IComponentRepository componentRepository,
        IDroneConfigurationRepository configurationRepository,
        IDroneCalculationService calculationService)
    {
        _componentRepository = componentRepository;
        _configurationRepository = configurationRepository;
        _calculationService = calculationService;
    }

    public IEnumerable<ComponentDto> GetAvailableComponents()
    {
        return _componentRepository.GetAll().Select(MapToDto);
    }

    public IEnumerable<ComponentDto> GetComponentsByType(ComponentType type)
    {
        return _componentRepository.GetByType(type).Select(MapToDto);
    }

    public ComponentDto? GetComponentById(string id)
    {
        var component = _componentRepository.GetById(id);
        return component != null ? MapToDto(component) : null;
    }

    public ConfigurationDto GetCurrentConfiguration()
    {
        var config = _configurationRepository.GetCurrentConfiguration();
        var performance = _calculationService.CalculatePerformance(config.PlacedComponents);
        
        return new ConfigurationDto
        {
            Id = config.Id,
            Name = config.Name,
            Description = config.Description,
            PlacedComponents = config.PlacedComponents.Select(MapToPlacedDto).ToList(),
            Hierarchy = MapToHierarchyDto(config.Hierarchy),
            SimulationState = config.SimulationState.ToString(),
            Performance = new PerformanceDto
            {
                TotalWeight = performance.TotalWeight,
                TotalThrust = performance.TotalThrust,
                ThrustToWeightRatio = performance.ThrustToWeightRatio,
                EstimatedFlightTime = performance.EstimatedFlightTime,
                TotalPowerConsumption = performance.TotalPowerConsumption,
                PerformanceRating = performance.PerformanceRating,
                IsValid = performance.IsValid,
                ValidationErrors = performance.ValidationErrors
            }
        };
    }

    public PlacedComponentDto PlaceComponent(PlaceComponentRequest request)
    {
        var component = _componentRepository.GetById(request.ComponentId);
        if (component == null)
            throw new ArgumentException($"Component with ID {request.ComponentId} not found.");
        
        var placed = new PlacedComponent
        {
            ComponentId = component.Id,
            Name = component.Name,
            ComponentType = component.Type,
            GridX = request.GridX,
            GridY = request.GridY,
            Width = component.Width,
            Height = component.Height,
            Rotation = 0,
            IconClass = component.IconClass,
            Color = component.Color,
            Weight = component.Weight,
            Thrust = component.Thrust,
            PowerConsumption = component.PowerConsumption,
            Capacity = component.Capacity,
            Voltage = component.Voltage
        };
        
        var savedComponent = _configurationRepository.AddPlacedComponent(placed);
        return MapToPlacedDto(savedComponent);
    }

    public PlacedComponentDto? UpdatePlacedComponent(UpdatePlacedComponentRequest request)
    {
        var existing = _configurationRepository.GetPlacedComponents()
            .FirstOrDefault(c => c.InstanceId == request.InstanceId);
        
        if (existing == null)
            return null;
        
        existing.GridX = request.GridX ?? existing.GridX;
        existing.GridY = request.GridY ?? existing.GridY;
        existing.Rotation = request.Rotation ?? existing.Rotation;
        existing.IsSelected = request.IsSelected ?? existing.IsSelected;
        
        var updated = _configurationRepository.UpdatePlacedComponent(existing);
        return updated != null ? MapToPlacedDto(updated) : null;
    }

    public bool RemovePlacedComponent(string instanceId)
    {
        return _configurationRepository.RemovePlacedComponent(instanceId);
    }

    public void ClearAllComponents()
    {
        _configurationRepository.ClearAllComponents();
    }

    public HierarchyNodeDto GetHierarchy()
    {
        return MapToHierarchyDto(_configurationRepository.GetHierarchy());
    }

    public HierarchyNodeDto AddLayer(string name, string? parentId)
    {
        var hierarchy = _configurationRepository.GetHierarchy();
        var newLayer = new HierarchyNode
        {
            Id = Guid.NewGuid().ToString(),
            Name = name,
            IsExpanded = true,
            IsLayer = true,
            ParentId = parentId ?? "root",
            Children = new List<HierarchyNode>()
        };

        if (string.IsNullOrEmpty(parentId) || parentId == "root")
        {
            hierarchy.Children.Add(newLayer);
        }
        else
        {
            var parentNode = FindNodeById(hierarchy, parentId);
            if (parentNode != null)
            {
                parentNode.Children.Add(newLayer);
            }
            else
            {
                hierarchy.Children.Add(newLayer);
            }
        }

        _configurationRepository.UpdateHierarchy(hierarchy);
        return MapToHierarchyDto(newLayer);
    }

    public bool MoveNodeToParent(string nodeId, string newParentId)
    {
        var hierarchy = _configurationRepository.GetHierarchy();
        
        // Find and remove node from current parent
        var node = FindAndRemoveNode(hierarchy, nodeId);
        if (node == null) return false;

        // Update parent reference
        node.ParentId = newParentId;

        // Add to new parent
        if (newParentId == "root")
        {
            hierarchy.Children.Add(node);
        }
        else
        {
            var newParent = FindNodeById(hierarchy, newParentId);
            if (newParent != null)
            {
                newParent.Children.Add(node);
                newParent.IsExpanded = true;
            }
            else
            {
                // Parent not found, add to root
                hierarchy.Children.Add(node);
            }
        }

        _configurationRepository.UpdateHierarchy(hierarchy);
        return true;
    }

    public bool DeleteLayer(string layerId)
    {
        var hierarchy = _configurationRepository.GetHierarchy();
        var layer = FindNodeById(hierarchy, layerId);
        
        if (layer == null || !layer.IsLayer) return false;

        // Move children to parent before deleting
        var parentId = layer.ParentId ?? "root";
        foreach (var child in layer.Children.ToList())
        {
            child.ParentId = parentId;
            if (parentId == "root")
            {
                hierarchy.Children.Add(child);
            }
            else
            {
                var parent = FindNodeById(hierarchy, parentId);
                parent?.Children.Add(child);
            }
        }

        // Remove the layer
        FindAndRemoveNode(hierarchy, layerId);
        _configurationRepository.UpdateHierarchy(hierarchy);
        return true;
    }

    private HierarchyNode? FindNodeById(HierarchyNode root, string id)
    {
        if (root.Id == id) return root;
        foreach (var child in root.Children)
        {
            var found = FindNodeById(child, id);
            if (found != null) return found;
        }
        return null;
    }

    private HierarchyNode? FindAndRemoveNode(HierarchyNode parent, string nodeId)
    {
        for (int i = 0; i < parent.Children.Count; i++)
        {
            if (parent.Children[i].Id == nodeId)
            {
                var node = parent.Children[i];
                parent.Children.RemoveAt(i);
                return node;
            }
            var found = FindAndRemoveNode(parent.Children[i], nodeId);
            if (found != null) return found;
        }
        return null;
    }

    public SimulationResultDto StartSimulation()
    {
        var config = _configurationRepository.GetCurrentConfiguration();
        var performance = _calculationService.CalculatePerformance(config.PlacedComponents);
        
        if (!performance.IsValid)
        {
            return new SimulationResultDto
            {
                Success = false,
                State = SimulationState.Stopped.ToString(),
                Message = "Cannot start simulation. Configuration is invalid.",
                Errors = performance.ValidationErrors
            };
        }
        
        config.SimulationState = SimulationState.Running;
        _configurationRepository.SaveConfiguration(config);
        
        return new SimulationResultDto
        {
            Success = true,
            State = SimulationState.Running.ToString(),
            Message = "Simulation started successfully."
        };
    }

    public SimulationResultDto PauseSimulation()
    {
        var config = _configurationRepository.GetCurrentConfiguration();
        
        if (config.SimulationState != SimulationState.Running)
        {
            return new SimulationResultDto
            {
                Success = false,
                State = config.SimulationState.ToString(),
                Message = "Cannot pause. Simulation is not running."
            };
        }
        
        config.SimulationState = SimulationState.Paused;
        _configurationRepository.SaveConfiguration(config);
        
        return new SimulationResultDto
        {
            Success = true,
            State = SimulationState.Paused.ToString(),
            Message = "Simulation paused."
        };
    }

    public SimulationResultDto StopSimulation()
    {
        var config = _configurationRepository.GetCurrentConfiguration();
        config.SimulationState = SimulationState.Stopped;
        _configurationRepository.SaveConfiguration(config);
        
        return new SimulationResultDto
        {
            Success = true,
            State = SimulationState.Stopped.ToString(),
            Message = "Simulation stopped."
        };
    }

    public SimulationState GetSimulationState()
    {
        return _configurationRepository.GetCurrentConfiguration().SimulationState;
    }

    #region Mapping Methods

    private static ComponentDto MapToDto(DroneComponent component)
    {
        return new ComponentDto
        {
            Id = component.Id,
            Name = component.Name,
            Type = component.Type.ToString(),
            Description = component.Description,
            Weight = component.Weight,
            Thrust = component.Thrust,
            PowerConsumption = component.PowerConsumption,
            Capacity = component.Capacity,
            Voltage = component.Voltage,
            IconClass = component.IconClass,
            Color = component.Color,
            Width = component.Width,
            Height = component.Height
        };
    }

    private static PlacedComponentDto MapToPlacedDto(PlacedComponent placed)
    {
        return new PlacedComponentDto
        {
            InstanceId = placed.InstanceId,
            ComponentId = placed.ComponentId,
            Name = placed.Name,
            Type = placed.ComponentType.ToString(),
            GridX = placed.GridX,
            GridY = placed.GridY,
            Width = placed.Width,
            Height = placed.Height,
            Rotation = placed.Rotation,
            IsSelected = placed.IsSelected,
            IconClass = placed.IconClass,
            Color = placed.Color
        };
    }

    private static HierarchyNodeDto MapToHierarchyDto(HierarchyNode node)
    {
        return new HierarchyNodeDto
        {
            Id = node.Id,
            Name = node.Name,
            IsExpanded = node.IsExpanded,
            IsLayer = node.IsLayer,
            ParentId = node.ParentId,
            ComponentInstanceId = node.ComponentInstanceId,
            Children = node.Children.Select(MapToHierarchyDto).ToList()
        };
    }

    #endregion
}
