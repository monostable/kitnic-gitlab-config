class Uniquify
  # Return a version of the given 'base' string that is unique
  # by appending a counter to it. Uniqueness is determined by
  # repeated calls to the passed block.
  #
  # If `base` is a function/proc, we expect that calling it with a
  # candidate counter returns a string to test/return.
  def string(base)
    @base = base
    @counter = nil

    increment_counter! while yield(base_string)
    base_string
  end

  private

  def base_string
    if @base.respond_to?(:call)
      @base.call(@counter)
    else
      "#{@base}#{@counter}"
    end
  end

  def increment_counter!
    @counter ||= 0
    @counter += 1
  end
end
