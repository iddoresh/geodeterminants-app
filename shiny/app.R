library(shiny)
library(bslib)
library(DT)
library(shinyjs)
library(shinycssloaders)
library(dplyr)
library(readr)
library(geodeterminants)
library(tidycensus)

GROUP_CODES <- list(
  "White alone (non-Hispanic/Latino)"    = list(acs = "B03002_003", dhc = "P5_003N", sf1 = "P005003"),
  "Black or African American alone"      = list(acs = "B03002_004", dhc = "P5_004N", sf1 = "P005004"),
  "American Indian / Alaska Native"      = list(acs = "B03002_005", dhc = "P5_005N", sf1 = "P005005"),
  "Asian alone"                          = list(acs = "B03002_006", dhc = "P5_006N", sf1 = "P005006"),
  "Native Hawaiian / Pacific Islander"   = list(acs = "B03002_007", dhc = "P5_007N", sf1 = "P005007"),
  "Hispanic or Latino (any race)"        = list(acs = "B03002_012", dhc = "P5_010N", sf1 = "P005010")
)

SDOH_MODULES <- c(
  "Air Quality Index (EPA)",
  "Concentrated Poverty",
  "Education Attainment",
  "Environmental Justice Index (EPA EJSCREEN)",
  "Retail Food Environment Index (Food Swamp)",
  "Income Concentration at Extremes (ICE)",
  "Minimum Wage",
  "Percent Unionized Workforce",
  "Race/Ethnic Dissimilarity Index",
  "Race/Ethnic Separation Index",
  "Decennial Dissimilarity Index",
  "Social Vulnerability Index (CDC)"
)

KEY_FILE   <- "/srv/geodeterminants/api_key.rds"
SAMPLE_CSV <- "sample_addresses.csv"

ENV_API_KEY <- Sys.getenv("CENSUS_API_KEY", unset = "")
HOSTED_MODE <- nchar(ENV_API_KEY) > 0

load_api_key <- function() {
  if (HOSTED_MODE) return(ENV_API_KEY)
  if (file.exists(KEY_FILE)) tryCatch(readRDS(KEY_FILE), error = function(e) "") else ""
}

save_api_key <- function(key) {
  if (HOSTED_MODE) return(invisible(NULL))
  dir.create(dirname(KEY_FILE), recursive = TRUE, showWarnings = FALSE)
  tryCatch(saveRDS(key, KEY_FILE), error = function(e) NULL)
}

translate_error <- function(msg) {
  if (grepl("API key|census_api_key|Unauthorized|401", msg, ignore.case = TRUE)) {
    "Census API key not recognized. Please check your key at api.census.gov."
  } else if (grepl("geocod|nominatim|no results|lat|lon", msg, ignore.case = TRUE)) {
    "Geocoding failed for one or more addresses. Check that each address includes a city and state."
  } else if (grepl("internet|connection|timeout|curl", msg, ignore.case = TRUE)) {
    "Network error. Please check your internet connection and try again."
  } else {
    paste0("Analysis error: ", substr(msg, 1, 120))
  }
}

# --- UI ---
ui <- page_sidebar(
  title = tags$span(style = "font-weight: 600; letter-spacing: -0.5px;", "Geodeterminants"),
  theme = bs_theme(
    bootswatch   = "flatly",
    primary      = "#2563EB",
    base_font    = font_google("Inter"),
    heading_font = font_google("Inter")
  ),
  useShinyjs(),

  sidebar = sidebar(
    width = 340,

    h6("1. Enter addresses", class = "text-muted text-uppercase fw-semibold mt-1 mb-2"),
    radioButtons("input_mode", NULL,
                 choices  = c("Type or paste" = "paste", "Upload CSV" = "upload"),
                 inline   = TRUE,
                 selected = "paste"),

    conditionalPanel(
      condition = "input.input_mode == 'paste'",
      textAreaInput("address_text", NULL, rows = 7, width = "100%",
                    placeholder = paste0(
                      "One address per line, e.g.:\n",
                      "15 Main Street, Flemington, NJ 08822\n",
                      "401 W 14th St, Austin, TX 78701\n",
                      "1600 Pennsylvania Ave NW, Washington, DC 20500"
                    ))
    ),

    conditionalPanel(
      condition = "input.input_mode == 'upload'",
      fileInput("file", NULL, accept = ".csv",
                buttonLabel = "Choose CSV...",
                placeholder = "No file selected"),
      downloadLink("download_example", icon("download"), " Download example CSV",
                   style = "font-size: 0.85em;"),
      hr(style = "margin: 10px 0;"),
      h6("Map your columns", class = "text-muted text-uppercase fw-semibold mb-2"),
      uiOutput("col_mapping")
    ),

    hr(style = "margin: 10px 0;"),
    h6("2. Population group of interest", class = "text-muted text-uppercase fw-semibold mb-2"),
    selectInput("minority_group", "Group of interest",
                choices  = names(GROUP_CODES),
                selected = "Black or African American alone"),
    selectInput("comparison_group", "Comparison group",
                choices  = names(GROUP_CODES),
                selected = "White alone (non-Hispanic/Latino)"),

    hr(style = "margin: 10px 0;"),
    h6("3. Parameters", class = "text-muted text-uppercase fw-semibold mb-2"),
    numericInput("current_year", "Data year",
                 value = as.integer(format(Sys.Date(), "%Y")),
                 min = 2010, max = 2030, step = 1),
    numericInput("fed_min_wage", "Federal minimum wage ($)",
                 value = 7.25, min = 0, step = 0.01),

    hr(style = "margin: 10px 0;"),
    if (HOSTED_MODE) {
      tags$p(
        icon("circle-check", style = "color: #22c55e; margin-right: 4px;"),
        tags$small("Census API key configured"),
        class = "text-muted mb-2"
      )
    } else {
      tagList(
        h6("4. Census API key", class = "text-muted text-uppercase fw-semibold mb-2"),
        passwordInput("api_key", NULL,
                      value       = load_api_key(),
                      placeholder = "Paste your Census API key"),
        tags$small(
          tags$a("Get a free key at api.census.gov",
                 href   = "https://api.census.gov/data/key_signup.html",
                 target = "_blank"),
          " (free, takes ~1 minute)"
        ),
        checkboxInput("save_key", "Remember key for future sessions", value = TRUE)
      )
    },

    hr(style = "margin: 10px 0;"),
    actionButton("run", "Analyze Addresses",
                 class = "btn btn-primary btn-lg w-100",
                 icon  = icon("play"))
  ),

  uiOutput("main_content")
)

# --- Server ---
server <- function(input, output, session) {

  results <- reactiveVal(NULL)

  observeEvent(input$input_mode,   { results(NULL) }, ignoreInit = TRUE)
  observeEvent(input$address_text, { results(NULL) }, ignoreInit = TRUE)
  observeEvent(input$file,         { results(NULL) }, ignoreInit = TRUE)

  data <- reactive({
    req(input$file)
    tryCatch(
      read_csv(input$file$datapath, show_col_types = FALSE),
      error = function(e) {
        showNotification("Could not read that file. Please upload a CSV (.csv) file.",
                         type = "error", duration = 8)
        NULL
      }
    )
  })

  output$col_mapping <- renderUI({
    df <- data()
    if (is.null(df)) {
      return(tags$p(tags$em("Upload a CSV file above to map columns."),
                    class = "text-muted", style = "font-size: 0.85em;"))
    }
    cols      <- names(df)
    addr_idx  <- grep("^address$|^addr$|street|full.?addr", cols, ignore.case = TRUE)[1]
    state_idx <- grep("^state$|^st$", cols, ignore.case = TRUE)[1]
    year_idx  <- grep("^year$|^yr$|date", cols, ignore.case = TRUE)[1]

    tagList(
      selectInput("col_address", "Address column", choices = cols,
                  selected = if (!is.na(addr_idx)) cols[addr_idx] else cols[1]),
      selectInput("col_state", "State column",
                  choices  = c("(none — state included in address)" = "_none_", cols),
                  selected = if (!is.na(state_idx)) cols[state_idx] else "_none_"),
      selectInput("col_year", "Year column",
                  choices  = c("(use default: current year - 2)" = "_none_", cols),
                  selected = if (!is.na(year_idx)) cols[year_idx] else "_none_")
    )
  })

  output$main_content <- renderUI({
    if (!is.null(results())) {
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          tags$span(
            icon("circle-check", style = "color: #22c55e; margin-right: 6px;"),
            paste0("Results — ", nrow(results()), " addresses enriched")
          ),
          downloadButton("download_results", "Download CSV", class = "btn-success btn-sm")
        ),
        card_body(
          style = "padding: 0;",
          withSpinner(DTOutput("results_table"), color = "#2563EB")
        )
      )
    } else if (input$input_mode == "upload" && !is.null(data())) {
      card(
        card_header(
          paste0("Uploaded: ", input$file$name,
                 " — ", nrow(data()), " rows, ", ncol(data()), " columns")
        ),
        card_body(
          tags$p("Map the columns on the left, then click ",
                 tags$strong("Analyze Addresses"), "."),
          withSpinner(DTOutput("preview_table"), color = "#2563EB")
        )
      )
    } else {
      card(
        card_header(class = "bg-primary text-white",
                    tags$h5("Social Determinants of Health Enrichment", class = "mb-0")),
        card_body(
          tags$p(
            "Enrich a list of addresses with social and environmental data — ",
            "no programming required."
          ),
          tags$p(
            tags$strong("Two ways to provide addresses:"),
            tags$ul(
              tags$li(tags$strong("Type or paste"), " — paste one address per line directly into the box on the left"),
              tags$li(tags$strong("Upload CSV"), " — upload a spreadsheet with an address column")
            )
          ),
          tags$p(tags$strong("What you get back (12 data modules):")),
          tags$ul(lapply(SDOH_MODULES, tags$li)),
          tags$hr(),
          tags$p(
            tags$strong("Tip: "),
            "Include city and state in each address for best results. ",
            "Example: ", tags$code("15 Main Street, Flemington, NJ 08822")
          )
        )
      )
    }
  })

  output$preview_table <- renderDT({
    req(data())
    datatable(head(data(), 10),
              options  = list(pageLength = 5, scrollX = TRUE, dom = "tp"),
              rownames = FALSE)
  })

  output$results_table <- renderDT({
    req(results())
    datatable(results(),
              options    = list(pageLength = 10, scrollX = TRUE, dom = "Bfrtip"),
              rownames   = FALSE,
              extensions = "Buttons")
  })

  observeEvent(input$run, {
    active_key <- if (HOSTED_MODE) ENV_API_KEY else trimws(input$api_key)

    if (nchar(active_key) == 0) {
      showNotification("Please enter your Census API key.", type = "warning", duration = 8)
      return()
    }

    # mode-specific input validation
    address_vector <- NULL
    if (input$input_mode == "paste") {
      raw <- if (is.null(input$address_text)) "" else input$address_text
      raw <- gsub("\r", "", raw)
      lines <- trimws(unlist(strsplit(raw, "\n")))
      address_vector <- lines[nchar(lines) > 0]
      if (length(address_vector) == 0) {
        showNotification("Please enter at least one address.", type = "warning")
        return()
      }
    } else {
      if (is.null(data())) {
        showNotification("Please upload a CSV file first.", type = "warning")
        return()
      }
    }

    if (!HOSTED_MODE && isTRUE(input$save_key)) {
      tryCatch(save_api_key(active_key), error = function(e) NULL)
    }

    tryCatch(
      tidycensus::census_api_key(active_key, install = FALSE, overwrite = TRUE),
      error = function(e) Sys.setenv(CENSUS_API_KEY = active_key)
    )

    minority   <- GROUP_CODES[[input$minority_group]]
    comparison <- GROUP_CODES[[input$comparison_group]]

    withProgress(message = "Analyzing addresses...", value = 0, {

      if (input$input_mode == "paste") {
        incProgress(0.1, detail = paste0("Processing ", length(address_vector), " addresses..."))

        result <- tryCatch({
          incProgress(0, detail = "Geocoding and fetching Census data (this may take a minute)...")
          res <- geodeterminants::get_geodeterminants(
            gd_tib                     = NULL,
            gd_addresses               = address_vector,
            gd_current_year            = as.integer(input$current_year),
            gd_minority_group_code     = minority$acs,
            gd_comparison_group_code   = comparison$acs,
            gd_minority_group_code_dhc = minority$dhc,
            gd_minority_group_code_sf1 = minority$sf1,
            gd_current_fed_min_wage    = as.numeric(input$fed_min_wage)
          )
          incProgress(0.8, detail = "Finalizing results...")
          res
        }, error = function(e) {
          showNotification(translate_error(conditionMessage(e)), type = "error", duration = 12)
          NULL
        })

      } else {
        incProgress(0.05, detail = "Reading your data...")

        tib <- data()
        if (!is.null(input$col_address) && input$col_address != "address") {
          tib <- tib %>% rename(address = !!sym(input$col_address))
        }
        if (!is.null(input$col_state) && input$col_state != "_none_" &&
            input$col_state != "address") {
          if (input$col_state != "state") tib <- tib %>% rename(state = !!sym(input$col_state))
        } else if (!"state" %in% names(tib)) {
          tib$state <- NA_character_
        }
        if (!is.null(input$col_year) && input$col_year != "_none_") {
          if (input$col_year != "year") tib <- tib %>% rename(year = !!sym(input$col_year))
          tib$year <- suppressWarnings(as.integer(tib$year))
        } else if (!"year" %in% names(tib)) {
          tib$year <- as.integer(input$current_year) - 2L
        }

        incProgress(0.1, detail = "Geocoding addresses...")

        result <- tryCatch({
          incProgress(0, detail = "Fetching Census and EPA data (this may take a minute)...")
          res <- geodeterminants::get_geodeterminants(
            gd_tib                     = tib,
            gd_addresses               = NULL,
            gd_current_year            = as.integer(input$current_year),
            gd_minority_group_code     = minority$acs,
            gd_comparison_group_code   = comparison$acs,
            gd_minority_group_code_dhc = minority$dhc,
            gd_minority_group_code_sf1 = minority$sf1,
            gd_current_fed_min_wage    = as.numeric(input$fed_min_wage)
          )
          incProgress(0.8, detail = "Finalizing results...")
          res
        }, error = function(e) {
          showNotification(translate_error(conditionMessage(e)), type = "error", duration = 12)
          NULL
        })
      }

      incProgress(1.0, detail = "Done!")
      results(result)
    })
  })

  output$download_results <- downloadHandler(
    filename = function() paste0("geodeterminants_results_", Sys.Date(), ".csv"),
    content  = function(file) write_csv(results(), file)
  )

  output$download_example <- downloadHandler(
    filename = "sample_addresses.csv",
    content  = function(file) {
      src <- if (file.exists(SAMPLE_CSV)) SAMPLE_CSV else "sample_addresses.csv"
      file.copy(src, file)
    }
  )
}

shinyApp(ui, server)
