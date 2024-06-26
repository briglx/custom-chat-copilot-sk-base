﻿// Copyright (c) Microsoft. All rights reserved.

namespace ClientApp.Components;

public sealed partial class Answer
{
    [Parameter, EditorRequired] public required ApproachResponse Retort { get; set; }
    [Parameter, EditorRequired] public required EventCallback<string> FollowupQuestionClicked { get; set; }
 

    [Inject] public required IDialogService Dialog { get; set; }

    private HtmlParsedAnswer? _parsedAnswer;
    private int _newRating;

    private async Task OnPositiveFeedbackClickedAsync()
    {
        _newRating = 5;
        Dialog.Show<FeedbackDialog>($"Provide additional feedback",
            new DialogParameters
            {
                [nameof(FeedbackDialog.Rating)] = _newRating,
                [nameof(FeedbackDialog.MessageId)] = Retort.Context.MessageId.ToString(),
                [nameof(FeedbackDialog.ChatId)] = Retort.Context.ChatId.ToString(),
            },
            new DialogOptions
            {
                MaxWidth = MaxWidth.Medium,
                CloseButton = true,
                CloseOnEscapeKey = true
            });
    }

    private async Task OnNegativeFeedbackClickedAsync()
    {
        _newRating = 0;
        Dialog.Show<FeedbackDialog>($"Provide additional feedback",
            new DialogParameters
            {
                [nameof(FeedbackDialog.Rating)] = _newRating,
                [nameof(FeedbackDialog.MessageId)] = Retort.Context.MessageId.ToString(),
                [nameof(FeedbackDialog.ChatId)] = Retort.Context.ChatId.ToString(),
            },
            new DialogOptions
            {
                MaxWidth = MaxWidth.Medium,
                CloseButton = true,
                CloseOnEscapeKey = true
            });
    }

    private async Task OnRatingClickedAsync(int val)
    {
        _newRating = val;
        Dialog.Show<FeedbackDialog>($"Provide additional feedback",
            new DialogParameters
            {
                [nameof(FeedbackDialog.Rating)] = _newRating,
                [nameof(FeedbackDialog.MessageId)] = Retort.Context.MessageId.ToString(),
                [nameof(FeedbackDialog.ChatId)] = Retort.Context.ChatId.ToString(),
            },
            new DialogOptions
            {
                MaxWidth = MaxWidth.Medium,
                CloseButton = true,
                CloseOnEscapeKey = true
            });
    }

    protected override void OnParametersSet()
    {
        _parsedAnswer = ParseAnswerToHtml(
            Retort.Answer, Retort.CitationBaseUrl);

        base.OnParametersSet();
    }

    private async Task OnAskFollowupAsync(string followupQuestion)
    {
        if (FollowupQuestionClicked.HasDelegate)
        {
            await FollowupQuestionClicked.InvokeAsync(followupQuestion);
        }
    }

    private void OnShowCitation(CitationDetails citation)
    {
        Dialog.Show<PdfViewerDialog>($"📄 {citation.Name}",
            new DialogParameters
            {
                [nameof(PdfViewerDialog.FileName)] = citation.Name.Replace(" ", "_"),
                [nameof(PdfViewerDialog.BaseUrl)] = citation.BaseUrl,
            },
            new DialogOptions
            {
                MaxWidth = MaxWidth.Large,
                FullWidth = true,
                CloseButton = true,
                CloseOnEscapeKey = true
            });
    }

    private MarkupString RemoveLeadingAndTrailingLineBreaks(string input) => (MarkupString)HtmlLineBreakRegex().Replace(input, "");

    [GeneratedRegex("^(\\s*<br\\s*/?>\\s*)+|(\\s*<br\\s*/?>\\s*)+$", RegexOptions.Multiline)]
    private static partial Regex HtmlLineBreakRegex();
}
