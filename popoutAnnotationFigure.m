function [] = popoutAnnotationFigure(app)
%Pop-out the the annotation figure into a new external figure window,
%Oliver Pambos, 31/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: popoutAnnotationFigure
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD, UK
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%LEGAL DISCLAIMER
%THIS CODE IS INTENDED FOR USE ONLY BY INDIVIDUALS WHO HAVE RECEIVED
%EXPLICIT AUTHORIZATION FROM THE AUTHOR, OLIVER JAMES PAMBOS. ANY FORM OF
%COPYING, REDISTRIBUTION, OR UNAUTHORIZED USE OF THIS CODE, IN WHOLE OR IN
%PART, IS PROHIBITED. BY USING THIS CODE, USERS SIGNIFY THAT THEY HAVE
%READ, UNDERSTOOD, AND AGREED TO BE BOUND BY THE TERMS OF SERVICE PRESENTED
%UPON SOFTWARE LAUNCH, INCLUDING THE REQUIREMENT FOR CO-AUTHORSHIP ON ANY
%RELATED PUBLICATIONS. THIS APPLIES TO ALL LEVELS OF USE, INCLUDING PARTIAL
%USE OR MODIFICATION OF THE CODE OR ANY OF ITS EXTERNAL FUNCTIONS.
%
%USERS ARE RESPONSIBLE FOR ENSURING FULL UNDERSTANDING AND COMPLIANCE WITH
%THESE TERMS, INCLUDING OBTAINING AGREEMENT FROM THE APPROPRIATE
%PUBLICATION DECISION-MAKERS WITHIN THEIR ORGANIZATION OR INSTITUTION.
%
%NOTE: UPON PUBLIC RELEASE OF THIS SOFTWARE, THESE TERMS MAY BE SUBJECT TO
%CHANGE. HOWEVER, USERS OF THIS PRE-RELEASE VERSION ARE STILL BOUND BY THE
%CO-AUTHORSHIP AGREEMENT FOR ANY USE MADE PRIOR TO THE PUBLIC RELEASE. THE
%RELEASED VERSION WILL BE AVAILABLE FROM A DESIGNATED ONLINE REPOSITORY
%WITH POTENTIALLY DIFFERENT USAGE CONDITIONS.
%
%
%This code has been moved from a GUI callback into this external .m file to
%improve code readability and interpretability.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %new figure with dimensions matching GUI UIAxes
    h_popout_fig = figure('Color', 'white');
    set(h_popout_fig, 'Units', get(app.AnnotationUIAxes, 'Units'));
    set(h_popout_fig, 'Position', get(app.AnnotationUIAxes, 'Position'));
    ax_new = axes('Parent', h_popout_fig);
    
    %copy properties from UIAxes to new figure
    ax_props = {'XLim', 'YLim', 'ZLim', 'YLabel', 'ZLabel', 'Title', 'View', ...
                'XScale', 'YScale', 'ZScale', 'GridLineStyle', 'MinorGridLineStyle', ...
                'FontSize', 'FontName', 'FontWeight', 'FontAngle', 'Box', ...
                'XColor', 'XTick', 'XTickLabel'};
    for ii = 1:numel(ax_props)
        set(ax_new, ax_props{ii}, get(app.AnnotationUIAxes, ax_props{ii}));
    end
    
    %ensure line widths for yyaxis left are moved to new figure
    ax_new.YAxis(1).LineWidth = app.AnnotationUIAxes.YAxis(1).LineWidth;
    ax_new.XAxis(1).LineWidth = app.AnnotationUIAxes.XAxis(1).LineWidth;
    
    %save titles and labels
    xlabel_text = app.AnnotationUIAxes.XLabel.String;
    ylabel_left_text = '';
    ylabel_right_text = '';
    if isprop(app.AnnotationUIAxes, 'YAxisLocation')
        yyaxis(app.AnnotationUIAxes, 'left');
        ylabel_left_text = app.AnnotationUIAxes.YLabel.String;
        yyaxis(app.AnnotationUIAxes, 'right');
        ylabel_right_text = app.AnnotationUIAxes.YLabel.String;
    end
    
    %copy left axis (feature vs time) data
    yyaxis(app.AnnotationUIAxes, 'left');
    yyaxis(ax_new, 'left');
    left_yprops = {'YColor', 'YLabel', 'YTick', 'YTickLabel', 'YLim'};
    for ii = 1:numel(left_yprops)
        set(ax_new, left_yprops{ii}, get(app.AnnotationUIAxes, left_yprops{ii}));
    end
    left_children = get(app.AnnotationUIAxes, 'Children');
    for ii = 1:length(left_children)
        child = copyobj(left_children(ii), ax_new);
        if isprop(child, 'LineWidth')
            child.LineWidth = left_children(ii).LineWidth;
        end
    end
    
    %copy right axis (annotation) data
    yyaxis(app.AnnotationUIAxes, 'right');
    yyaxis(ax_new, 'right');
    right_yprops = {'YColor', 'YLabel', 'YTick', 'YTickLabel', 'YLim'};
    for ii = 1:numel(right_yprops)
        set(ax_new, right_yprops{ii}, get(app.AnnotationUIAxes, right_yprops{ii}));
    end
    right_children = get(app.AnnotationUIAxes, 'Children');
    for ii = 1:length(right_children)
        child = copyobj(right_children(ii), ax_new);
        if isprop(child, 'LineWidth')
            child.LineWidth = right_children(ii).LineWidth;
        end
    end
    
    %ensure line width for y-axis of yyaxis right are moved to new figure
    if numel(app.AnnotationUIAxes.YAxis) > 1
        ax_new.YAxis(2).LineWidth = app.AnnotationUIAxes.YAxis(2).LineWidth;
    end
    
    %copy over axes info. to new figure
    ax_new.XLabel.String = xlabel_text;
    yyaxis(ax_new, 'left');
    ax_new.YLabel.String = ylabel_left_text;
    yyaxis(ax_new, 'right');
    ax_new.YLabel.String = ylabel_right_text;
    app.AnnotationUIAxes.XLabel.String = xlabel_text;
    yyaxis(app.AnnotationUIAxes, 'left');
    app.AnnotationUIAxes.YLabel.String = ylabel_left_text;
    yyaxis(app.AnnotationUIAxes, 'right');
    app.AnnotationUIAxes.YLabel.String = ylabel_right_text;
    
    % %copy over the legend - temporarily disabled due to issue with order of text entries desyncronising with order of line colours only in external plot
    % if ~isempty(app.AnnotationUIAxes.Legend)
    %     legend_entries = app.AnnotationUIAxes.Legend.String;
    %     legend(ax_new, legend_entries, 'Location', app.AnnotationUIAxes.Legend.Location);
    % end
    
    %adjust the figure window size to ensure axis titles fit
    set(ax_new, 'Units', 'Normalized', 'Position', [0.13, 0.15, 0.775, 0.775]);
end