server <- function(input, output, session) {
  # require(cognitive.index.lookup)
  # list.files(here::here("R"),full.names = TRUE) |> lapply(source)
  # source(here::here("R/index_from_raw.R"))
  # source(here::here("R/plot_index.R"))
  # source(here::here("R/read_file.R"))
  # index_table <- read.csv(here::here("data-raw/index_table.csv"))

  library(tidyr)
  library(patchwork)
  library(ggplot2)
  library(dplyr)
  library(tidyselect)
  library(openxlsx2)
  library(readr)
  library(purrr)

  # source("https://raw.githubusercontent.com/agdamsbo/cognitive.index.lookup/main/R/index_from_raw.R")
  # source("https://raw.githubusercontent.com/agdamsbo/cognitive.index.lookup/main/R/plot_index.R")
  # source("https://raw.githubusercontent.com/agdamsbo/cognitive.index.lookup/main/R/read_file.R")
  source("https://raw.githubusercontent.com/agdamsbo/cognitive.index.lookup/main/app/functions.R")
  index_table <- read.csv("https://raw.githubusercontent.com/agdamsbo/cognitive.index.lookup/main/data-raw/index_table.csv")

  # To allow shinylive running, functions are directly sourced:
  # source("https://raw.githubusercontent.com/agdamsbo/cognitive.index.lookup/main/R/index_from_raw.R")
  # source("https://raw.githubusercontent.com/agdamsbo/cognitive.index.lookup/main/R/plot_index.R")

  # source(here::here("R/index_from_raw.R"))
  # source(here::here("R/plot_index.R"))


  dat <- shiny::reactive({
    shiny::req(input$ab)
    shiny::req(input$age)
    shiny::req(input$rs1)
    shiny::req(input$rs2)
    shiny::req(input$rs3)
    shiny::req(input$rs4)
    shiny::req(input$rs5)
    
    data.frame(
      "id" = "1",
      "ab" = input$ab,
      "age" = input$age,
      "imm" = input$rs1,
      "vis" = input$rs2,
      "ver" = input$rs3,
      "att" = input$rs4,
      "del" = input$rs5,
      stringsAsFactors = FALSE
    )
  })

  dat_u <- shiny::reactive({
    # input$file1 will be NULL initially. After the user selects
    # and uploads a file, head of that data file by default,
    # or all rows if selected, will be shown.


    shiny::req(input$file1)

    # read.csv(input$file1$datapath,
    #                header = input$header,
    #                sep = input$sep,
    #                quote = input$quote
    # )
    read_input(input$file1$datapath)
  })

  output$id_sel <- shiny::renderUI({
    selectInput(
      inputId = "id_col",
      selected = "id",
      label = "ID column",
      choices = colnames(dat_u()),
      multiple = FALSE
    )
  })

  output$ab_sel <- shiny::renderUI({
    selectInput(
      inputId = "ab_col",
      selected = NULL,
      label = "Version column (optional)",
      choices = c("none", colnames(dat_u())),
      multiple = FALSE
    )
  })

  output$age_sel <- shiny::renderUI({
    selectInput(
      inputId = "age_col",
      selected = "age",
      label = "Age column",
      choices = colnames(dat_u()),
      multiple = FALSE
    )
  })

  output$imm_sel <- shiny::renderUI({
    selectInput(
      inputId = "imm_col",
      selected = "imm",
      label = "Immediate memory",
      choices = colnames(dat_u()),
      multiple = FALSE
    )
  })


  output$vis_sel <- shiny::renderUI({
    selectInput(
      inputId = "vis_col",
      selected = "vis",
      label = "Visuospatial functions",
      choices = colnames(dat_u()),
      multiple = FALSE
    )
  })


  output$ver_sel <- shiny::renderUI({
    selectInput(
      inputId = "ver_col",
      selected = "ver",
      label = "Verbal functions",
      choices = colnames(dat_u()),
      multiple = FALSE
    )
  })


  output$att_sel <- shiny::renderUI({
    selectInput(
      inputId = "att_col",
      selected = "att",
      label = "Attention",
      choices = colnames(dat_u()),
      multiple = FALSE
    )
  })


  output$del_sel <- shiny::renderUI({
    selectInput(
      inputId = "del_col",
      selected = "del",
      label = "Delayed memory",
      choices = colnames(dat_u()),
      multiple = FALSE
    )
  })

  dat_f <- shiny::reactive({
    if (input$type == 1) {
      dat()
    } else if (input$type == 2) {
      # browser()

      dat <- dat_u()
      cols <- list(
        input$id_col,
        input$ab_col,
        input$age_col,
        input$imm_col,
        input$vis_col,
        input$ver_col,
        input$att_col,
        input$del_col
      )

      if (any(is.null(cols)) | any(!(cols %in% c("none", names(dat))))) {
        return()
      }
      # browser()
      ds <- cols |>
        purrr::map(\(.x){
          if (.x == "none") {
            dat |>
              dplyr::mutate(.x = 1) |>
              dplyr::select(.x)
          } else {
            dplyr::select(dat, .x)
          }
        }) |>
        dplyr::bind_cols(.name_repair = "unique_quiet") |>
        stats::setNames(c("id", "ab", "age", "imm", "vis", "ver", "att", "del"))

      if (length(unique(ds$ab)) == 1) {
        ds <- ds |>
          dplyr::filter(!duplicated(id))
      }

      return(ds)
    }
  })

  v <- shiny::reactiveValues(
    index = NULL
  )

  shiny::observeEvent(
    {
      input$load
    },
    {
      # if (input$type == 1)

      v$index <- dat_f() |> index_from_raw(
        indx = index_table,
        version.col = "ab",
        age.col = "age",
        raw_columns = c("imm", "vis", "ver", "att", "del")
      )

      output$ndx.tbl <- shiny::renderTable({
        v$index |>
          dplyr::select("id", "ab", dplyr::contains("_is")) |>
          setNames(c("ID", "ab", "imm", "vis", "ver", "att", "del", "Total"))
      })

      output$per.tbl <- shiny::renderTable({
        v$index |>
          dplyr::select("id", "ab", dplyr::contains("_per")) |>
          setNames(c("ID", "ab", "imm", "vis", "ver", "att", "del", "Total"))
      })


      output$ndx.plt <- shiny::renderPlot({
        v$index |> plot_index(sub_plot = "_is", facet.by = "ab", plot.ci = input$ci)
      })

      output$per.plt <- shiny::renderPlot({
        v$index |> plot_index(sub_plot = "_per", facet.by = "ab")
      })
    }
  )

  # Downloadable csv of selected dataset ----
  output$downloadData <- shiny::downloadHandler(
    filename = "index_lookup.csv",
    content = function(file) {
      write.csv(v$index, file, row.names = FALSE)
    }
  )
}
