// <copyright file="AgregarMapaSacadosInput.cs" company="Banco Fibra">
// Direitos autorais (c) Banco Fibra. Todos os direitos reservados.
// </copyright>

using Fibra.Operacoes.Boletador.FCT.Application.DTOs.Output;

namespace Fibra.Operacoes.Boletador.FCT.Application.DTOs.Input;

/// <summary>
/// Input do agregador que recebe o array de resultados parciais do Map State de sacados.
/// </summary>
public record AgregarMapaSacadosInput
{
    /// <summary>CorrelationId propagado pelo SF para preservar o trace da execução.</summary>
    public string? CorrelationId { get; init; }

    /// <summary>NrBoleto propagado para fins de log.</summary>
    public long NumeroBoleto { get; init; }

    /// <summary>Resultados parciais de cada página processada pelo Map State.</summary>
    public IReadOnlyList<SalvarLoteSacadosResultDto> Resultados { get; init; } = [];
}
 
