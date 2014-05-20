require File.dirname(__FILE__) + '/square'
require File.dirname(__FILE__)  + '/../lib/multi_methods'


describe "hacking Square with multi_methods" do

  describe "defmulti_local" do
    before(:each) do
      @our_square.dispatch_fn = nil
      @our_square.class.dispatch_fn = nil
    end

    before(:all) do
      class Square

        def tuna1 *args
          @dispatch_fn = :tuna1
          return 69
        end

        def tuna_gateway *args
          defmulti_local do  
            defmulti :tuna, lambda{ |*args| args[0] + args[1] }
            defmethod :tuna, 2, self.class.instance_method(:tuna1)
            defmethod :tuna, 4, self.class.method(:tuna2)
            defmethod :tuna, :default, lambda{ |*args| @default_fn = :tuna_default }

            tuna(*args) 
          end
        end
      end

      @our_square = Square.new
    end
    
    it "should dispatch to tuna1 when the sum of the first to parameters is 2" do
      secret = @our_square.tuna_gateway(1,1)
      @our_square.dispatch_fn.should == :tuna1
      @our_square.class.dispatch_fn.should == nil
    end

    it "should dispatch to tuna2 when the sum of the first to parameters is 4" do
      @our_square.tuna_gateway(3,1)
      @our_square.dispatch_fn.should == nil
      @our_square.class.dispatch_fn.should == :tuna2
    end

    it "should remove all traces of metaprogramming after the defmulti_local block exits" do
      @our_square.tuna_gateway(3,1)
      @our_square.methods.should_not include 'tuna'
      @our_square.class.instance_variables.should_not include '@tuna'
      @our_square.class.instance_variables.should_not include '@added_multi_method'
    end 

    it "should return the value of whatever fn it dispatched to" do
      secret = @our_square.tuna_gateway(1,1)
      secret.should == 69
    end
  end

  describe "causes of exceptions" do
    before do
      @our_square = Square.new
    end
    it "should raise an exception if trying to construct a defmethod without a previously defined defmulti of the same name" do
      lambda do
        @our_square.class.instance_eval { defmethod :chicken, lambda{ |*args| args[0] }, instance_method(:chicken1) }
      end.should raise_error( Exception, "MultiMethod chicken not defined" )
    end

    it "should raise an exception if no predicates match and there is no default defmethod" do
      @our_square.class.instance_eval do
        defmulti :chicken, lambda{ |*args| args[1].class }
        defmethod :chicken, Fixnum, instance_method(:chicken1)
        defmethod :chicken, String, method(:chicken2)
      end
      lambda { @our_square.chicken( true ) }.should raise_error( Exception, "No matching dispatcher function found" )
    end

    it "should raise an exception if defining individual dispatch predicates AND a default dispatch fn" do
      @our_square.class.instance_eval do
        defmulti :chicken, lambda{ |*args| args[1].class }
        defmethod :chicken, Fixnum, instance_method(:chicken1)
        defmethod :chicken, String, method(:chicken2)
        defmethod :chicken, lambda { |*args| true }, lambda { |*args| puts "never get here" }
      end
      lambda do 
        @our_square.chicken(2)
      end.should raise_error( Exception, "Dispatch method already defined by defmulti" )
    end

  end

  describe "class level with a single dispatch fn" do
    describe "dispatch by on type of 2nd arg" do
      before do
        @our_square = Square.new

        @our_square.class.instance_eval do
          defmulti :chicken, lambda{ |*args| args[1].class }
          defmethod :chicken, Fixnum, instance_method(:chicken1)
          defmethod :chicken, String, method(:chicken2)
          defmethod :chicken, :default, lambda { @dispatch_fn = :chicken_default; return :chicken_default }
        end

        @our_square.dispatch_fn = nil
        @our_square.class.dispatch_fn = nil
      end
      
      it "should create an instance method named chicken and a class level instance variable" do
        @our_square.methods.should include 'chicken'
        @our_square.class.instance_variables.should include '@chicken'
      end

      it "should dispatch to chicken1 if the 2nd arg is a Fixnum" do
        @our_square.chicken( true, 2 )
        @our_square.dispatch_fn.should == :chicken1
        @our_square.class.dispatch_fn.should be_nil
      end

      it "should dispatch to chicken1 if the 2nd arg is a Fixnum and return the correct value from chicken1" do
        result = @our_square.chicken( true, 2 )
        result.should == :chicken1
      end

      it "should dispatch to chicken2 if the 2nd arg is a String" do
        @our_square.chicken( true, "two" )
        @our_square.dispatch_fn.should be_nil
        @our_square.class.dispatch_fn.should == :chicken2
      end

      it "should dispatch to the default lambda if the 2nd arg is neither a Fixnum nor a String and return the correct value" do
        result = @our_square.chicken( true, true )
        @our_square.dispatch_fn.should be_nil
        @our_square.class.dispatch_fn.should == :chicken_default
        result.should == :chicken_default
      end
    end

    describe "dispatch based on the # of args " do
      before do
        @our_square = Square.new

        @our_square.class.instance_eval do
          defmulti :chicken, lambda{ |*args| args.size }
          defmethod :chicken, 1, instance_method(:chicken1)
          defmethod :chicken, 2, method(:chicken2)
          defmethod :chicken, :default, lambda { @dispatch_fn = :chicken_default}
        end

        @our_square.dispatch_fn = nil
        @our_square.class.dispatch_fn = nil
      end

      it "should dispatch to chicken1 if called with one arg" do
        @our_square.chicken(1)
        @our_square.dispatch_fn.should == :chicken1
        @our_square.class.dispatch_fn.should be_nil
      end

      it "should dispatch to chicken2 if called with two args" do
        @our_square.chicken(1,2)
        @our_square.dispatch_fn.should be_nil
        @our_square.class.dispatch_fn.should == :chicken2
      end

      it "should dispatch to chicken3 if called with three args" do
        @our_square.chicken(1,2,3)
        @our_square.class.dispatch_fn.should == :chicken_default
        @our_square.dispatch_fn.should be_nil
      end

      it "should dispatch to chicken3 if called with four args" do
        @our_square.chicken(1,2,3,4)
        @our_square.class.dispatch_fn.should == :chicken_default
        @our_square.dispatch_fn.should be_nil
      end
    end 
  end

  describe "class level with multiple predicates" do
      before do
        @our_square = Square.new

        @our_square.class.instance_eval do
          defmulti :chicken
          defmethod :chicken, lambda{ |*args| args[0].class == Fixnum && args[1].class == Fixnum }, instance_method(:chicken1)
          defmethod :chicken, lambda{ |*args| args[0].class == String && args[1].class  == String }, method(:chicken2)
          defmethod :chicken, :default, lambda { @dispatch_fn = :chicken_default}
        end

        @our_square.dispatch_fn = nil
        @our_square.class.dispatch_fn = nil
      end

      it "should dispatch to chicken1 if the first two parameters are Fixnums" do
        result = @our_square.chicken(1, 2)
        @our_square.dispatch_fn.should == :chicken1
        @our_square.class.dispatch_fn.should be_nil
      end

      it "should dispatch to chicken2 if the first two parameters are Strings" do
        @our_square.chicken("one", "two")
        @our_square.dispatch_fn.should be_nil 
        @our_square.class.dispatch_fn.should == :chicken2
      end

      it "should dispatch to chicken3 if the first two parameters are neither Fixnums or Strings" do
        @our_square.chicken("one", 2)
        @our_square.dispatch_fn.should be_nil 
        @our_square.class.dispatch_fn.should == :chicken_default
      end
  end

  describe "default method" do
    it "should only be called if no other methods match" do
      @our_square = Square.new
      @our_square.class.instance_eval do
        defmulti :puppy, lambda { |*args| args[0] }
        defmethod :puppy, 1, lambda { |*args| :one }
        defmethod :puppy, :default, lambda { |*args| :default }
        defmethod :puppy, 2, lambda { |*args| :two }
      end

      result = @our_square.puppy 2
      result.should == :two
      
    end
  end

  describe "arg splatting" do
    before(:all) do
      @our_square = Square.new
      @our_square.class.instance_eval do
        def glorb a, b=nil
          [a, b]
        end
        defmulti :kitten, lambda { |a| a }
        defmethod :kitten, 1, lambda { |a, b| [a,b] }
        defmethod :kitten, 2, lambda { |a, b, c| [a,b,c] }
        defmethod :kitten, 3, lambda { |a, b, c, d| [a,b,c,d] }
        defmethod :kitten, 4, lambda { |*args| args.reverse }
        defmethod :kitten, 5, method(:glorb)
        defmethod :kitten, 6, lambda { |a, *rest| [a, rest] }
        defmethod :kitten, :default, lambda { |*args| args }
      end
    end

    it "should pass the number of args the lambda is expecting when it doesn't want a splatted list" do
      @our_square.kitten(1,:b,:c,:d,:e,:f,:g).should == [1, :b]
      @our_square.kitten(2,:b,nil,:d,:e,:f,:g).should == [2, :b, nil]
      @our_square.kitten(3,:b,nil,[:d],:e,:f,:g).should == [3, :b, nil, [:d]]
      @our_square.kitten(:guava,:b,:c,:d,:e,:f,:g).should == [:guava, :b, :c, :d, :e, :f, :g]
      @our_square.kitten(5).should == [5, nil]
      @our_square.kitten(5, :b).should == [5, :b]
    end

    it "should raise an argument exception if there are not enough arguments to satisfy the required args for a dispatch_fn" do
      lambda { @our_square.kitten(1) }.should raise_error( Exception, "wrong number of arguments (1 for 2)" )
    end

    it "should not raise an argument exception if there are not enough arguments to satisfy optional args for a dispatch_fn" do
      lambda { @our_square.kitten(5) }.should_not raise_error( Exception, "wrong number of arguments (1 for 2)" )
    end

    it "should raise an argument exception if there are too many arguments for a method" do
      #NOTE: not sure why the exception is saying (3 for 1), :glorb takes 2 arguments, second is optional
      lambda { @our_square.kitten(5,:b,:c) }.should raise_error(Exception, "wrong number of arguments (3 for 1)")
    end 

    it "should pass the entire arg array when the lambda is expecting one splatted arg" do
      @our_square.kitten(4,:b,:c,:d,:e,:f,:g).should == [4,:b,:c,:d,:e,:f,:g].reverse
    end

    it "should pass the correct number of args plus rest in the splatted args list when the dispatch_fn takes multiple args and a splatted arg" do
      @our_square.kitten(6).should == [6,[]]
      @our_square.kitten(6,:b,:c).should == [6, [:b, :c]]
    end

  end

end
