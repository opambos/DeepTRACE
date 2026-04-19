function [] = exportNotes(app)
%Export the current analysis notes as a PDF file, 20/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%Exports the user's notes to a wide range of different formats, currently
%including,
%   - PDF
%   - Plain text
%   - Rich text
%   - LaTeX
%   - Markdown
%   - HTML
%
%Note that the current implementation of PDF export will only export a
%single page due to restrictions in MATLAB's standard toolbox. Future
%version will perform assessment of PDF length prior to rendering using
%a fixed-width font, and then write to multiple PDF files with consecutive
%filename suffixes.
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
%convertToRTF()         - local to this .m file
%convertToLaTeX()       - local to this .m file
%convertToMarkdown()    - local to this .m file
%convertToHTML()        - local to this .m file
%sanitiseFileName()     - local to this .m file
    
    %check filepath is known
    if ~isprop(app, "movie_data") || ~isfield(app.movie_data, "params") ||...
            ~isfield(app.movie_data.params, "ffPath") || isempty(app.movie_data.params.ffPath)
        warndlg("In order to save the analysis notes you must load a valid analysis file, which contains a base filepath. " + newline + ...
            "If you would like to save your current notes, you are also able to select the text manually and copy this to a text " + ...
            "or word processor by selecting the text above and copy & pasting into another application.", ...
            "Warning: no valid dataset is currently loaded");
            
        return;
    end
    
    %check if the Analysis notes folder exists, create if not
    notes_path = fullfile(app.movie_data.params.ffPath, 'Analysis notes');
    if ~exist(notes_path, 'dir')
        mkdir(notes_path);
    end
    
    %get the strings that make up the file title: first row of the file description (this is sanitised, see f'n), user name, and date-time stamp
    file_title  = sanitiseFileName(string(app.movie_data.params.title));
    if isfield(app.movie_data.params, "user") && ~isempty(app.movie_data.params.user)
        username = app.movie_data.params.user;
    else
        username = "Default user";
    end
    timestamp   = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    
    %concatenate notes text
    original_text   = app.DataanalysisnotesTextArea.Value;
    formatted_text  = strjoin(original_text, '\n');
    
    app.textout.Value = "Please select a file name and location for your analysis notes.";
    switch app.NotesexportformatDropDown.Value
        case "PDF (.pdf)"
            %suggested filename
            notes_filename = sprintf('[%s]_%s', file_title, 'analysis_notes.pdf');
            
            %user specifies filename, and check if user presses cancel
            [file, path] = uiputfile('*.pdf', 'Save notes to PDF file', fullfile(notes_path, notes_filename));
            if isequal(file, 0) || isequal(path, 0)
                return;
            end
            
            full_notes_text = sprintf('%s\n\n%s', file_title, formatted_text);
            
            %create temporary figure for printing to PDF
            fig = figure('Visible', 'off');
            uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0 0 1 1], 'String', full_notes_text, ...
                      'HorizontalAlignment', 'left', 'BackgroundColor', 'white', 'FontSize', 10);
            
            %print to PDF
            print(fig, fullfile(path, file), '-dpdf', '-fillpage');
            
            %close the figure
            close(fig);
            
        case "Plain text (.txt)"
            %suggested filename
            notes_filename = sprintf('[%s]_%s', file_title, 'analysis_notes.txt');
            
            %user specifies filename, and check if user presses cancel
            [file, path] = uiputfile('*.txt', 'Save notes to plain text file', fullfile(notes_path, notes_filename));
            if isequal(file, 0) || isequal(path, 0)
                return;
            end
            
            %write notes to the specified file
            full_pathname   = fullfile(path, file);
            file_ID         = fopen(full_pathname, 'w');
            
            %check file can be opened
            if file_ID == -1
                warndlg("Please make sure that you have access to the path " + path, ...
                    "Warning: Unable to write analysis notes to plain text file");
                    
                return;
            end
            
            fprintf(file_ID, '%s', formatted_text);
            fclose(file_ID);
            
        case "Rich text (.rtf)"
            %suggested filename
            notes_filename = sprintf("[%s]_%s", file_title, "analysis_notes.rtf");
            
            %user specifies filename, and check if user presses cancel
            [file, path] = uiputfile('*.rtf', 'Save notes to rich text file', fullfile(notes_path, notes_filename));
            if isequal(file, 0) || isequal(path, 0)
                return;
            end
            
            %convert to RTF
            rtf_text = convertToRTF(formatted_text, file_title, timestamp, username);
            
            %write to the specified file
            full_pathname   = fullfile(path, file);
            file_ID         = fopen(full_pathname, 'w');
            
            %check the file could be opened
            if file_ID == -1
                warndlg("Please make sure that you have access to the path " + path, ...
                        "Warning: Unable to write analysis notes to rich text file");
                return;
            end
            
            fprintf(file_ID, '%s', rtf_text);
            fclose(file_ID);
            
        case "LaTeX (.tex)"
            %suggested filename
            notes_filename = sprintf('[%s]_%s', file_title, 'analysis_notes.tex');
            
            %user specifies filename, and check if user presses cancel
            [file, path] = uiputfile('*.tex', 'Save notes to LaTeX file', fullfile(notes_path, notes_filename));
            if isequal(file, 0) || isequal(path, 0)
                return;
            end
            
            full_pathname = fullfile(path, file);
            
            %convert plain text to LaTeX formatted text and write to file
            convertToLaTeX(full_pathname, formatted_text, file_title, timestamp, username);
            
        case "Markdown (.md)"
            %suggested filename
            notes_filename = sprintf("[%s]_%s", file_title, "analysis_notes.md");
            
            %user specifies filename, and check if user presses cancel
            [file, path] = uiputfile('*.md', 'Save notes to Markdown file', fullfile(notes_path, notes_filename));
            if isequal(file, 0) || isequal(path, 0)
                return;
            end
            
            %convert to Markdown
            md_text = convertToMarkdown(formatted_text, file_title, timestamp, username);
            
            %write to the specified file
            full_pathname = fullfile(path, file);
            file_ID = fopen(full_pathname, 'w');
            
            %check the file could be opened
            if file_ID == -1
                warndlg("Please make sure that you have access to the path " + path, ...
                        "Warning: Unable to write analysis notes to Markdown file");
                return;
            end
            
            fprintf(file_ID, '%s', md_text);
            fclose(file_ID);
        
        case "HTML (.html)"
            %suggested filename
            notes_filename = sprintf("[%s]_%s", file_title, "analysis_notes.html");
            
            %user specifies filename, and check if user presses cancel
            [file, path] = uiputfile('*.html', 'Save notes to HTML file', fullfile(notes_path, notes_filename));
            if isequal(file, 0) || isequal(path, 0)
                return;
            end
            
            %convert to HTML
            html_text = convertToHTML(formatted_text, file_title, timestamp, username);
            
            %write to the specified file
            full_pathname = fullfile(path, file);
            file_ID = fopen(full_pathname, 'w');
            
            %check the file could be opened
            if file_ID == -1
                warndlg("Please make sure that you have access to the path " + path, ...
                        "Warning: Unable to write analysis notes to HTML file");
                return;
            end
            
            fprintf(file_ID, '%s', html_text);
            fclose(file_ID);
        
            %display the HTML file in a web browser
            web(full_pathname, '-browser');

        otherwise
        
    end
    
    
end


function [rtf_text] = convertToRTF(text, file_description, timestamp, username)
%Reformat plain text to rich text, and apply formatting of RTF document,
%20/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%This function reformats the plain text notes as rich text, includes the
%header&footer definitions, and escapes special characters that can cause
%problems for rich text. It also adds a title, and uses basic RTF
%formatting to separate this visually from the body text.
%
%Inputs
%------
%text               (str)   main text body of notes
%file_description   (str)   description of the experiment; taken from the
%                               first line of the `currently loaded
%                               dataset` field in the Load/Save tab
%timestamp          (str)   current date-time stored as string literal
%username           (str)   name of the user that performed the analysis;
%                               taken from `User` field in Load/Save tab
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %escape special RTF characters
    text = strrep(text, '\', '\\');
    text = strrep(text, '{', '\{');
    text = strrep(text, '}', '\}');
    
    %replace newline characters with RTF line breaks
    text = strrep(text, newline, '\par ');
    
    %format the document title
    title_text = "{\fs32\qc\b" + file_description + "\b0}\par" + "{\fs28\qc\b InVivoKinetics analysis notes \b0}\par" + ...
        "{\fs28\qc\b " + username + "\b0}\par" + "{\fs28\qc(notes exported on " + timestamp + ")}\par\par";
    
    %construct the RTF text
    rtf_text = ["{\rtf1\ansi" title_text text "}"];
end


function [] = convertToLaTeX(file_path, text, file_description, timestamp, username)
%Reformat plain text to LaTeX, and apply formatting and styling,
%20/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%This function reformats the plain text notes in LaTeX format, escapes
%special characters, constructs a title, shrinks the default margins,
%and saves the file to the specified path and filename.
%
%Inputs
%------
%file_path          (path)  location and filename for writing .tex file
%text               (str)   main text body of notes
%file_description   (str)   description of the experiment; taken from the
%                               first line of the `currently loaded
%                               dataset` field in the Load/Save tab
%timestamp          (str)   current date-time stored as string literal
%username           (str)   name of the user that performed the analysis;
%                               taken from `User` field in Load/Save tab
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %escape special LaTeX characters
    special_chars = {'%', '$', '#', '&', '_', '{', '}'};
    for ii = 1:length(special_chars)
        replace_char    = special_chars{ii};
        text            = strrep(text, replace_char, ['\' replace_char]);
    end
    
    %concat title and text
    full_text   = sprintf('%s', text);
    text        = strcat("\noindent ", strrep(full_text, newline, '\newline '));
    
    %prepare title, with date, username, etc.
    subtitle = "(notes exported on " + timestamp + ")";
    tex_title = "\title{" + file_description + " \large \\ \textit{" + subtitle + "}}" + "\author{" + username + "}" + ...
                "\date{}" + newline + "\maketitle" + newline + newline;
    
    %create and open file with write access
    file_ID = fopen(file_path, 'w');
    
    %check file could be opened
    if file_ID == -1
        warndlg("Please make sure that you have access to the path " + file_path, ...
                "Warning: Unable to write analysis notes to LaTeX file");
        return;
    end
    
    %write each part of the LaTeX document to the file
    fprintf(file_ID, '%s\n', '\documentclass{article}');
    fprintf(file_ID, '%s\n', '\usepackage[margin=1in]{geometry}');
    fprintf(file_ID, '%s\n', '\begin{document}');
    fprintf(file_ID, '%s\n', tex_title);
    
    %split the text into lines and write each line
    text_lines = splitlines(text);
    for ii = 1:length(text_lines)
        fprintf(file_ID, '%s\n', text_lines(ii));
    end
    
    fprintf(file_ID, '%s\n', '\end{document}');
    fclose(file_ID);
end


function [md_text] = convertToMarkdown(text, file_description, timestamp, username)
%Reformat plain text as markdown, apply formatting and styling, 23/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%This function reformats the plain text notes in markdown format,
%constructs a title, and returns the formatted text as a new string that
%can be written directly to a markdown file.
%
%Inputs
%------
%text               (str)   main text body of notes
%file_description   (str)   description of the experiment; taken from the
%                               first line of the `currently loaded
%                               dataset` field in the Load/Save tab
%timestamp          (str)   current date-time stored as string literal
%username           (str)   name of the user that performed the analysis;
%                               taken from `User` field in Load/Save tab
%
%Output
%------
%md_text            (str)   markdown-formatted notes text
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %construct md text
    md_title = "# " + file_description + newline + "## InVivoKinetics analysis notes" + newline + ...
               "### " + username + newline + "*notes exported on " + timestamp + "*" + newline + newline;

    %construct full md text
    md_text = md_title + replace(text, newline, newline);
end


function [html_text] = convertToHTML(text, file_description, timestamp, username)
%Reformat plain text to HTML, apply formatting and styling, 23/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%This function reformats the plain text notes in HTML format, escapes
%special characters, constructs a title, and returns the formatted text as
%a new string that can be written directly to an HTML file.
%
%Inputs
%------
%text               (str)   main text body of notes
%file_description   (str)   description of the experiment; taken from the
%                               first line of the `currently loaded
%                               dataset` field in the Load/Save tab
%timestamp          (str)   current date-time stored as string literal
%username           (str)   name of the user that performed the analysis;
%                               taken from `User` field in Load/Save tab
%
%Output
%------
%html_text          (str)   HTML-formatted notes text
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %escape special HTML characters
    text = strrep(text, '&', '&amp;');
    text = strrep(text, '<', '&lt;');
    text = strrep(text, '>', '&gt;');
    
    %replace newline chars with HTML line breaks
    text = strrep(text, newline, '<br>');
    
    %format document title and text
    title_text = "<h1>" + file_description + "</h1><h2>InVivoKinetics analysis notes</h2>" + ...
                 "<h3>" + username + "</h3><p><i>notes exported on " + timestamp + "</i></p>";
    
    %construct the HTML text (UTF-8 encoding here enables user to use Greek characters in their notes)
    html_text = "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>" + file_description + "</title></head><body>" + ...
                title_text + text + "</body></html>";
end


function [sanitised_title] = sanitiseFileName(title)
%Replaces all chars that cause problems for filenames with underscores,
%23/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%Specific chars can cause issues for filenames, and this varies depending
%upon the operating system. This function sanitises the string that is used
%to suggest filenames, replacing these chars with underscores.
%
%Inputs
%------
%title              (str)   original string
%
%Output
%------
%sanitised_title    (str)   original string with forbidden chars replaced
%                               with `_`s.
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %define list of chars forbidden in path/filenames
    invalid_chars = {'\', '/', ':', '*', '?', '"', '<', '>', '|'};
    
    %replace each invalid character with an underscore or remove them
    sanitised_title = title;
    for ii = 1:length(invalid_chars)
        sanitised_title = strrep(sanitised_title, invalid_chars{ii}, '_');
    end
end