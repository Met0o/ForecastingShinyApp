aggregate_time_series <-
function(data, time_unit = "month") {
    
    output_tbl <- data %>%
        
        mutate(date = floor_date(date, unit = time_unit)) %>%
        
        group_by(date) %>%
        summarize(total_price = sum(price)) %>%
        ungroup() %>%
        
        mutate(label_text = str_glue("Date: {date}
                                 Price: {scales::dollar(total_price)}")) # Adding label text for the plotting function
    
    return(output_tbl)
    
}
plot_time_series <-
function(data) {
    
    g <- data %>%
        
        ggplot(aes(date, total_price)) +
        
        geom_line() +
        geom_point(aes(text = label_text), color = "#b1000e", size = 0.1) +
        geom_smooth(method = "loess", span = 0.2) +
        
        theme_tq() +
        expand_limits(y = 0) +
        scale_y_continuous(labels = scales::dollar_format()) +
        labs(x = "", y = "")
    
    
    ggplotly(g, tooltip = "text")
    
}
generate_forecast <-
function(data, n_future = 12, seed = NULL) {
    
    train_tbl <- data %>% 
        tk_augment_timeseries_signature()
    
    future_data_tbl <- data %>%
        tk_index() %>%
        tk_make_future_timeseries(n_future = n_future, inspect_weekdays = TRUE, inspect_months = TRUE) %>%
        tk_get_timeseries_signature() 
    
    time_scale <- data %>%
        tk_index() %>%
        tk_get_timeseries_summary() %>%
        pull(scale)
    
    if (time_scale == "year") {
        
        model <- linear_reg(mode = "regression") %>%
            set_engine(engine = "lm") %>%
            fit.model_spec(total_price ~ ., data = train_tbl %>% select(total_price, index.num))
        
    } else {
        seed <- seed
        set.seed(seed)
        model <- boost_tree(
            mode = "regression",
            mtry = 20,
            trees = 800,
            min_n = 3,
            tree_depth = 10,
            learn_rate = 0.01,
            loss_reduction = 0.01) %>%
            set_engine(engine = "xgboost") %>%
            fit.model_spec(total_price ~ ., data = train_tbl %>% select(-date, -label_text, -diff))
    }
    
    
    prediction_tbl <- predict(model, new_data = future_data_tbl) %>%
        bind_cols(future_data_tbl) %>%
        select(.pred, index) %>%
        rename(total_price = .pred, 
               date        = index) %>%
        mutate(label_text = str_glue("Date: {date}
                                 Price: {scales::dollar(total_price)}")) %>%
        add_column(key = "Prediction")
    
    output_tbl <- data %>%
        add_column(key = "Actual") %>%
        bind_rows(prediction_tbl) 
    
    return(output_tbl)
}
plot_forecast <-
function(data) {
    
    # Yearly - LM Smoother
    time_scale <- data %>%
        tk_index() %>%
        tk_get_timeseries_summary() %>%
        pull(scale)
    
    # Only 1 Prediction - points
    n_predictions <- data %>%
        filter(key == "Prediction") %>%
        nrow()
    
    
    g <- data %>%
        ggplot(aes(date, total_price, color = key)) +
        
        geom_line() +
        # geom_point(aes(text = label_text), size = 0.01) +
        # geom_smooth(method = "loess", span = 0.2) +
        
        theme_tq() +
        scale_color_tq() +
        scale_y_continuous(labels = scales::dollar_format()) +
        expand_limits(y = 0) +
        labs(x = "", y = "")
    
    # Yearly - LM Smoother
    if (time_scale == "year") {
        g <- g +
            geom_smooth(method = "lm")
    } else {
        g <- g + geom_smooth(method = "loess", span = 0.2)
    }
    
    # Only 1 Prediction
    if (n_predictions == 1) {
        g <- g + geom_point(aes(text = label_text), size = 1)
    } else {
        g <- g + geom_point(aes(text = label_text), size = 0.01)
    }
    
    ggplotly(g, tooltip = "text")
}
