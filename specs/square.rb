class Square
    class <<self 
      attr_accessor :dispatch_fn
    end
    attr_accessor :dispatch_fn 

  def chicken1 *args
    @dispatch_fn = :chicken1
    return :chicken1
  end

  def self.chicken2 *args
    @dispatch_fn = :chicken2
    return :chicken2
  end

  def tuna1 *args
    @dispatch_fn = :tuna1
  end

  def self.tuna2 *args
    @dispatch_fn = :tuna2
  end

end
