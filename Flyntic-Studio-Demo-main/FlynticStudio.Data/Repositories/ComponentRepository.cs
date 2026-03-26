using FlynticStudio.Data.Entities;
using FlynticStudio.Data.Enums;

namespace FlynticStudio.Data.Repositories;

/// <summary>
/// In-memory repository for drone components
/// </summary>
public class ComponentRepository : IComponentRepository
{
    private readonly Dictionary<string, DroneComponent> _components;

    public ComponentRepository()
    {
        _components = new Dictionary<string, DroneComponent>();
        SeedDefaultComponents();
    }

    public IEnumerable<DroneComponent> GetAll()
    {
        return _components.Values.ToList();
    }

    public DroneComponent? GetById(string id)
    {
        return _components.TryGetValue(id, out var component) ? component : null;
    }

    public IEnumerable<DroneComponent> GetByType(ComponentType type)
    {
        return _components.Values.Where(c => c.Type == type).ToList();
    }

    public DroneComponent Add(DroneComponent component)
    {
        component.Id = Guid.NewGuid().ToString();
        component.CreatedAt = DateTime.UtcNow;
        _components[component.Id] = component;
        return component;
    }

    public DroneComponent? Update(DroneComponent component)
    {
        if (!_components.ContainsKey(component.Id))
            return null;
        
        _components[component.Id] = component;
        return component;
    }

    public bool Delete(string id)
    {
        return _components.Remove(id);
    }

    private void SeedDefaultComponents()
    {
        var defaultComponents = new List<DroneComponent>
        {
            // Drone Bodies (Complete drone frame with arms)
            new DroneComponent
            {
                Id = "drone-body-quadcopter",
                Name = "Quadcopter Body",
                Type = ComponentType.Frame,
                Description = "Complete quadcopter body with 4 arms - ready for motors",
                Weight = 180,
                IconClass = "bi-bounding-box",
                Color = "#2c3e50",
                Width = 5,
                Height = 5
            },
            new DroneComponent
            {
                Id = "drone-body-hexacopter",
                Name = "Hexacopter Body",
                Type = ComponentType.Frame,
                Description = "Complete hexacopter body with 6 arms",
                Weight = 320,
                IconClass = "bi-hexagon",
                Color = "#1a252f",
                Width = 6,
                Height = 6
            },
            
            // Frames
            new DroneComponent
            {
                Id = "frame-carbon-250",
                Name = "Carbon Frame 250mm",
                Type = ComponentType.Frame,
                Description = "Lightweight carbon fiber quadcopter frame",
                Weight = 120,
                IconClass = "bi-grid-3x3",
                Color = "#2c3e50",
                Width = 4,
                Height = 4
            },
            new DroneComponent
            {
                Id = "frame-carbon-450",
                Name = "Carbon Frame 450mm",
                Type = ComponentType.Frame,
                Description = "Medium carbon fiber quadcopter frame",
                Weight = 280,
                IconClass = "bi-grid-3x3",
                Color = "#34495e",
                Width = 6,
                Height = 6
            },
            
            // Motors
            new DroneComponent
            {
                Id = "motor-2205-2300kv",
                Name = "Motor 2205 2300KV",
                Type = ComponentType.Motor,
                Description = "High-performance brushless motor",
                Weight = 28,
                Thrust = 0.8,
                PowerConsumption = 180,
                IconClass = "bi-gear-fill",
                Color = "#e74c3c",
                Width = 1,
                Height = 1
            },
            new DroneComponent
            {
                Id = "motor-2207-2400kv",
                Name = "Motor 2207 2400KV",
                Type = ComponentType.Motor,
                Description = "Racing brushless motor",
                Weight = 32,
                Thrust = 1.1,
                PowerConsumption = 220,
                IconClass = "bi-gear-fill",
                Color = "#c0392b",
                Width = 1,
                Height = 1
            },
            new DroneComponent
            {
                Id = "motor-2212-920kv",
                Name = "Motor 2212 920KV",
                Type = ComponentType.Motor,
                Description = "Efficient long-range motor",
                Weight = 52,
                Thrust = 0.65,
                PowerConsumption = 140,
                IconClass = "bi-gear-fill",
                Color = "#e67e22",
                Width = 1,
                Height = 1
            },
            
            // Propellers
            new DroneComponent
            {
                Id = "prop-5045",
                Name = "Propeller 5045",
                Type = ComponentType.Propeller,
                Description = "5-inch tri-blade propeller",
                Weight = 4,
                IconClass = "bi-fan",
                Color = "#27ae60",
                Width = 2,
                Height = 2
            },
            new DroneComponent
            {
                Id = "prop-6045",
                Name = "Propeller 6045",
                Type = ComponentType.Propeller,
                Description = "6-inch tri-blade propeller",
                Weight = 6,
                IconClass = "bi-fan",
                Color = "#2ecc71",
                Width = 2,
                Height = 2
            },
            
            // Batteries
            new DroneComponent
            {
                Id = "battery-4s-1500",
                Name = "LiPo 4S 1500mAh",
                Type = ComponentType.Battery,
                Description = "4-cell lithium polymer battery",
                Weight = 185,
                Capacity = 1500,
                Voltage = 14.8,
                IconClass = "bi-battery-full",
                Color = "#3498db",
                Width = 2,
                Height = 1
            },
            new DroneComponent
            {
                Id = "battery-4s-2200",
                Name = "LiPo 4S 2200mAh",
                Type = ComponentType.Battery,
                Description = "4-cell lithium polymer battery",
                Weight = 245,
                Capacity = 2200,
                Voltage = 14.8,
                IconClass = "bi-battery-full",
                Color = "#2980b9",
                Width = 3,
                Height = 1
            },
            new DroneComponent
            {
                Id = "battery-6s-1300",
                Name = "LiPo 6S 1300mAh",
                Type = ComponentType.Battery,
                Description = "6-cell lithium polymer battery",
                Weight = 210,
                Capacity = 1300,
                Voltage = 22.2,
                IconClass = "bi-battery-full",
                Color = "#9b59b6",
                Width = 2,
                Height = 1
            },
            
            // Flight Controllers
            new DroneComponent
            {
                Id = "fc-f4",
                Name = "Flight Controller F4",
                Type = ComponentType.FlightController,
                Description = "F4 processor flight controller",
                Weight = 8,
                PowerConsumption = 2,
                IconClass = "bi-cpu",
                Color = "#1abc9c",
                Width = 1,
                Height = 1
            },
            new DroneComponent
            {
                Id = "fc-f7",
                Name = "Flight Controller F7",
                Type = ComponentType.FlightController,
                Description = "F7 processor flight controller",
                Weight = 10,
                PowerConsumption = 3,
                IconClass = "bi-cpu-fill",
                Color = "#16a085",
                Width = 1,
                Height = 1
            },
            
            // ESCs
            new DroneComponent
            {
                Id = "esc-4in1-35a",
                Name = "4-in-1 ESC 35A",
                Type = ComponentType.ESC,
                Description = "4-in-1 electronic speed controller",
                Weight = 15,
                PowerConsumption = 0.5,
                IconClass = "bi-lightning-charge",
                Color = "#f39c12",
                Width = 2,
                Height = 2
            },
            
            // Camera
            new DroneComponent
            {
                Id = "camera-fpv",
                Name = "FPV Camera",
                Type = ComponentType.Camera,
                Description = "Low latency FPV camera",
                Weight = 8,
                PowerConsumption = 3,
                IconClass = "bi-camera-video",
                Color = "#e91e63",
                Width = 1,
                Height = 1
            },
            
            // GPS
            new DroneComponent
            {
                Id = "gps-m8n",
                Name = "GPS Module M8N",
                Type = ComponentType.GPS,
                Description = "High precision GPS module",
                Weight = 25,
                PowerConsumption = 0.5,
                IconClass = "bi-geo-alt",
                Color = "#00bcd4",
                Width = 1,
                Height = 1
            },
            
            // Receiver
            new DroneComponent
            {
                Id = "rx-elrs",
                Name = "ELRS Receiver",
                Type = ComponentType.Receiver,
                Description = "ExpressLRS long range receiver",
                Weight = 2,
                PowerConsumption = 0.3,
                IconClass = "bi-broadcast",
                Color = "#ff5722",
                Width = 1,
                Height = 1
            }
        };

        foreach (var component in defaultComponents)
        {
            _components[component.Id] = component;
        }
    }
}
