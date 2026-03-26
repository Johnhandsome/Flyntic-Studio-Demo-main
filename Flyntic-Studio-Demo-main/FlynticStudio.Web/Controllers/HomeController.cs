using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using FlynticStudio.Data.Entities;
using FlynticStudio.Data.DTOs;
using FlynticStudio.Services;

namespace FlynticStudio.Controllers;

/// <summary>
/// Main controller for the Flyntic Studio home page
/// </summary>
public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly IDroneAssemblyService _assemblyService;

    public HomeController(
        ILogger<HomeController> logger,
        IDroneAssemblyService assemblyService)
    {
        _logger = logger;
        _assemblyService = assemblyService;
    }

    /// <summary>
    /// Main studio view
    /// </summary>
    public IActionResult Index()
    {
        var viewModel = new StudioViewModel
        {
            Configuration = _assemblyService.GetCurrentConfiguration(),
            AvailableComponents = _assemblyService.GetAvailableComponents().ToList(),
            HierarchyTree = _assemblyService.GetHierarchy()
        };

        return View(viewModel);
    }

    /// <summary>
    /// Error page
    /// </summary>
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}

/// <summary>
/// View model for the studio page
/// </summary>
public class StudioViewModel
{
    public ConfigurationDto Configuration { get; set; } = new();
    public List<ComponentDto> AvailableComponents { get; set; } = new();
    public HierarchyNodeDto HierarchyTree { get; set; } = new();
}

/// <summary>
/// Error view model
/// </summary>
public class ErrorViewModel
{
    public string? RequestId { get; set; }
    public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);
}
