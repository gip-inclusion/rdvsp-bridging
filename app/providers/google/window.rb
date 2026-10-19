module Google
  module Window
    PAST = 7.days
    FUTURE = 6.months

    module_function

    def bounds = { time_min: PAST.ago, time_max: FUTURE.from_now }
  end
end
