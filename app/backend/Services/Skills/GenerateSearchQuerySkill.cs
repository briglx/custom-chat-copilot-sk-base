﻿// Copyright (c) Microsoft. All rights reserved.

using System.ComponentModel;
using Microsoft.SemanticKernel.ChatCompletion;
using MinimalApi.Extensions;
using MinimalApi.Services.Profile.Prompts;

namespace MinimalApi.Services.Skills;


public sealed class GenerateSearchQuerySkill
{
    [KernelFunction("GenerateSearchQuery"), Description("Generate a search query for user question.")]
    public async Task<string> GenerateSearchQueryAsync([Description("chat History")] ChatTurn[] chatTurns,
                                                       KernelArguments arguments,
                                                       Kernel kernel)
    {
        var chatGpt = kernel.Services.GetService<IChatCompletionService>();

        var chatHistory = new Microsoft.SemanticKernel.ChatCompletion.ChatHistory(PromptService.GetPromptByName(PromptService.RAGSearchSystemPrompt)).AddChatHistory(chatTurns);
        var userMessage = await PromptService.RenderPromptAsync(kernel, PromptService.GetPromptByName(PromptService.RAGSearchUserPrompt), arguments);
        chatHistory.AddUserMessage(userMessage);

        var searchAnswer = await chatGpt.GetChatMessageContentAsync(chatHistory, DefaultSettings.AISearchRequestSettings, kernel);
        arguments[ContextVariableOptions.SearchQuery] = searchAnswer.Content;

        return searchAnswer.Content;
    }
}
