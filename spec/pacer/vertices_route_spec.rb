require 'spec_helper'
require 'set'

include Pacer::Routes

describe GraphRoute do
  before do
    @g = Pacer.tg
  end

  describe '#v' do
    it { @g.v.should be_an_instance_of(VerticesRoute) }
  end

  describe '#e' do
    it { @g.e.should be_an_instance_of(EdgesRoute) }
  end

  it { @g.should_not be_is_a(RouteOperations) }
end


describe VerticesRoute do
  before do
    @g = Pacer.tg 'spec/data/pacer.graphml'
  end

  describe '#out_e' do
    it { @g.v.out_e.should be_an_instance_of(EdgesRoute) }
    it { @g.v.out_e(:label).should be_an_instance_of(EdgesRoute) }
    it { @g.v.out_e(:label) { |x| true }.should be_an_instance_of(EdgesRoute) }
    it { @g.v.out_e { |x| true }.should be_an_instance_of(EdgesRoute) }

    it { Set[*@g.v.out_e].should == Set[*@g.edges] }

    it { @g.v.out_e.count.should >= 1 }
  end
end

describe Base do
  before :all do
    @g = Pacer.tg 'spec/data/pacer.graphml'
  end

  describe '#graph' do
    it { @g.v.graph.should == @g }
    it { @g.v.out_e.graph.should == @g }
    it { @g.v.first.graph.should == @g }
    it { @g.v.in_e.first.graph.should == @g }
    it { @g.v.in_e.out_v.first.graph.should == @g }
  end

  describe '#to_a' do
    it { Set[*@g.v].should == Set[*@g.vertices] }
    it { Set[*(@g.v.to_a)].should == Set[*@g.vertices] }
    it { Set[*@g.e].should == Set[*@g.edges] }
    it { Set[*(@g.e.to_a)].should == Set[*@g.edges] }
    it { @g.v.to_a.count.should == @g.vertices.count }
    it { @g.e.to_a.count.should == @g.edges.count }
  end

  describe '#inspect' do
    it 'should show the path in the resulting string' do
      other_projects_by_gremlin_writer = 
        @g.v(:name => 'gremlin').as(:grem).in_e(:wrote).out_v.out_e(:wrote) { |e| true }.in_v.except(:grem)
      other_projects_by_gremlin_writer.inspect.should ==
        '#<Vertices([{:name=>"gremlin"}]) -> :grem -> Edges(IN_EDGES, [:wrote]) -> Vertices(OUT_VERTEX) -> Edges(OUT_EDGES, [:wrote], &block) -> Vertices(IN_VERTEX) -> Vertices(&block)>'
    end

    it { @g.inspect.should == '#<TinkerGraph>' }
  end

  describe '#root?' do
    it { @g.should be_root }
    it { @g.v.should be_root }
    it { @g.v[3].should_not be_root }
    it { @g.v.out_e.should_not be_root }
    it { @g.v.out_e.in_v.should_not be_root }
    it { @g.v.result.should be_root }
  end

  describe '#[]' do
    it { @g.v[2].count.should == 1 }
    it { @g.v[2].result.is_a?(Pacer::VertexMixin).should be_true }
  end

  describe '#from_graph?' do
    it { @g.v.should be_from_graph(@g) }
    it { @g.v.out_e.should be_from_graph(@g) }
    it { @g.v.out_e.should_not be_from_graph(Pacer.tg) }
  end

  describe '#each' do
    it { @g.v.each.should be_is_a(java.util.Iterator) }
    it { @g.v.out_e.each.should be_is_a(java.util.Iterator) }
    it { @g.v.each.to_a.should == @g.v.to_a }
  end

  describe 'property filter' do
    it { @g.v(:name => 'pacer').to_a.should == @g.v.select { |v| v[:name] == 'pacer' } }
    it { @g.v(:name => 'pacer').count.should == 1 }
  end

  describe 'block filter' do
    it { @g.v { false }.count.should == 0 }
    it { @g.v { true }.count.should == @g.v.count }
    it { @g.v { |v| v.out_e.none? }[:name].should == ['blueprints'] }
  end
end

describe RouteOperations do
  before :all do
    @g = Pacer.tg 'spec/data/pacer.graphml'
  end

  describe '#uniq' do
    it 'should be a route' do
      @g.v.uniq.should be_an_instance_of(VerticesRoute)
    end

    it 'results should be unique' do
      @g.e.in_v.group_count(:name).values.sort.last.should > 1
      @g.e.in_v.uniq.group_count(:name).values.sort.last.should == 1
    end
  end

  describe '#random' do
    it { Set[*@g.v.random(1)].should == Set[*@g.v] }
    it { @g.v.random(0).to_a.should == [] }
    it 'should have some number of elements more than 1 and less than all' do
      range = 1..(@g.v.count - 1)
      range.should include(@g.v.random(0.5).count)
    end
  end

  describe '#as' do
    it 'should set the variable to the correct node' do
      vars = Set[]
      @g.v.as(:a_vertex).in_e(:wrote) { |edge| vars << edge.vars[:a_vertex] }.count
      vars.should == Set[*@g.e(:wrote).in_v]
    end
  end

end

describe PathsRoute do
  before :all do
    @g = Pacer.tg 'spec/data/pacer.graphml'
  end

  describe '#paths' do
    it 'should return the paths between people and projects' do
      Set[*@g.v(:type => 'person').out_e.in_v(:type => 'project').paths].should ==
        Set[[@g.vertex(0), @g.edge(0), @g.vertex(1)],
            [@g.vertex(5), @g.edge(1), @g.vertex(4)],
            [@g.vertex(5), @g.edge(13), @g.vertex(2)],
            [@g.vertex(5), @g.edge(12), @g.vertex(3)]]
    end
  end

  describe '#transpose' do
    it 'should return the paths between people and projects' do
      Set[*@g.v(:type => 'person').out_e.in_v(:type => 'project').paths.transpose].should ==
        Set[[@g.vertex(0), @g.vertex(5), @g.vertex(5), @g.vertex(5)],
            [@g.edge(0), @g.edge(1), @g.edge(13), @g.edge(12)],
            [@g.vertex(1), @g.vertex(4), @g.vertex(2), @g.vertex(3)]]
    end
  end

  describe '#subgraph' do
    before do
      @sg = @g.v(:type => 'person').out_e.in_v(:type => 'project').subgraph

      @vertices = @g.v(:type => 'person').to_a + @g.v(:type => 'project').to_a
      @edges = @g.v(:type => 'person').out_e(:wrote)
    end

    it { Set[*@sg.v.ids].should == Set[*@vertices.map { |v| v.id }] }
    it { Set[*@sg.e.ids].should == Set[*@edges.map { |e| e.id }] }

    it { @sg.e.labels.uniq.should == ['wrote'] }
    it { Set[*@sg.v.map { |v| v.properties }].should == Set[*@vertices.map { |v| v.properties }] }
  end
end

describe BranchedRoute do
  before :all do
    @g = Pacer.tg 'spec/data/pacer.graphml'
    @br = @g.v(:type => 'person').
      branch { |b| b.out_e.in_v(:type => 'project') }.
      branch { |b| b.out_e.in_v.out_e }
  end

  describe '#inspect' do
    it 'should include both branches when inspecting' do
      @br.inspect.should ==
        '#<Vertices([{:type=>"person"}]) -> Branched { #<V -> Edges(OUT_EDGES) -> Vertices(IN_VERTEX, [{:type=>"project"}])> | #<V -> Edges(OUT_EDGES) -> Vertices(IN_VERTEX) -> Edges(OUT_EDGES)> }>'
    end
  end

  it 'should return matches in round robin order by default' do
    @br.to_a.should ==
      [@g.vertex(1), @g.edge(3),
       @g.vertex(4), @g.edge(2),
       @g.vertex(2), @g.edge(4),
       @g.vertex(3), @g.edge(6), @g.edge(5), @g.edge(7)]
  end

  it '#exhaustive should return matches in exhaustive merge order' do
    @br.exhaustive.to_a.should ==
      [@g.vertex(1), @g.vertex(4), @g.vertex(2), @g.vertex(3),
        @g.edge(3), @g.edge(2), @g.edge(4), @g.edge(6), @g.edge(5), @g.edge(7)]
  end

  it { @br.branch_count.should == 2 }
  it { @br.should_not be_root }

  describe '#mixed' do
    it { @br.mixed.to_a.should == @br.to_a }
  end

  describe 'chained branch routes' do
    describe 'once' do
      before do
        @once = @g.v.branch { |v| v.v }.branch { |v| v.v }.v
      end

      it 'should double each vertex' do
        @once.count.should == @g.v.count * 2
      end

      it 'should have 2 of each vertex' do
        @once.group_count { |v| v.id.to_i }.should == { 0 => 2, 1 => 2, 2 => 2, 3 => 2, 4 => 2, 5 => 2, 6 => 2 }
      end
    end

    describe 'twice' do
      before do
        @twice = @g.v.branch { |v| v.v }.branch { |v| v.v }.v.branch { |v| v.v }.branch { |v| v.v }.v
        @twice_e = @g.v.branch { |v| v.v }.branch { |v| v.v }.exhaustive.v.branch { |v| v.v }.branch { |v| v.v }.exhaustive.v
      end

      it 'should double each vertex' do
        pending 'bug in pipes'
        @twice.count.should == @g.v.count * 2 * 2
      end

      it 'should have 4 of each vertex' do
        pending 'bug in pipes'
        @twice.group_count { |v| v.id.to_i }.should == { 0 => 4, 1 => 4, 2 => 4, 3 => 4, 4 => 4, 5 => 4, 6 => 4 }
      end

      it 'should have 4 of each when exhaustive' do
        pending 'bug in pipes'
        @twice_e.group_count { |v| v.id.to_i }.should == { 0 => 4, 1 => 4, 2 => 4, 3 => 4, 4 => 4, 5 => 4, 6 => 4 }
      end
    end
  end

  describe 'repeating branch routes' do
  end

  describe 'route with a custom split pipe' do
    before do
      @r = @g.v.branch { |person| person.v }.branch { |project| project.v }.branch { |other| other.out_e }.split_pipe(Tackle::TypeSplitPipe).mixed
    end

    describe 'vertices' do
      it { @r.v.to_a.should == @r.v.uniq.to_a }
      it 'should have only all person and project vertices' do
        people_and_projects = Set[*@g.v(:type => 'person')] + Set[*@g.v(:type => 'project')]
        Set[*@r.v].should == people_and_projects
      end
    end

    describe 'edges' do
      it { @r.e.to_a.should == @r.e.uniq.to_a }
      it 'should have out edges from all vertices except person and project' do
        # TODO: this type of thing should be much easier
        people_and_projects = Set[*@g.v(:type => 'person')] + Set[*@g.v(:type => 'project')]
        vertices = @g.v.to_a - people_and_projects.to_a
        edges = Set[*vertices.map { |v| v.out_e.to_a }.flatten]
        Set[*@r.e].should == edges
      end
    end

    describe 'chained' do
      def add_branch(vertices_path)
        vertices_path.branch { |person| person.v }.branch { |project| project.v }.branch { |other| other.out_e.in_v }.split_pipe(Tackle::TypeSplitPipe).mixed
      end

      before do
        @r2 = add_branch(add_branch(@g.v))
      end

      describe 'via #repeat' do
        it 'should use the type splitter thing' do
          pending 'bug in pipes'
          pending 'Something is going wrong but I am not sure why. Not all elements matched by the first branch get passed into the next one.'
          @r4 = @g.v.repeat(4) { |repeater| add_branch(repeater) }
        end
      end
    end
  end
end