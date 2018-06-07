require 'spec_helper'

describe DataCorrelator::Correlators do

  before do
    TestClass.send :include, DataCorrelator::Correlators
  end

  let(:h){ TestClass.new } # A helper class to house the mixin

  let(:element_count){ 3 }
  let(:set_a){ TestModelFactory.create_list(element_count, prefix: 'A') }
  let(:set_b){ TestModelFactory.create_list(element_count, prefix: 'B') }
  let(:bogus_set){ set = [] ; element_count.times{|i| set << i} ; set }

  describe '#correlate' do

    it 'raises an error if you do not specify a block' do
      expect{ h.correlate([], []) }.to raise_error("Cannot correlate without a block, please pass a block!")
    end

    context 'when applied to matching sets (except for a prefix in their String attributes)' do

      it 'gives no correlations when the passed in block is forced to evaluate to false' do
        result = h.correlate(set_a, set_b){|a,b| false }
        expect(result.values.flatten).to be_empty
      end

      it 'correlates each element from A with all elements from B when the passed in block is forced to evaluate to true' do
        result = h.correlate(set_a, bogus_set){|a,b| true }
        # all values are the bogus set
        expect(result.values.uniq.flatten).to eq bogus_set
      end

      it 'corretly outputs a hash correlating the two when comparing by a unique matching attribute (:id)' do
        result = h.correlate(set_a, set_b){|a,b| a.id == b.id}
        result.each do |a, matches|
          match = matches.first
          expect(matches.count).to be 1 # check there is only one match for each
          # check the attributes are the same, except with a different prefix
          expect(test_same_non_prefixed_attributes(a, match)).to be true
        end
      end

      # Output the numbers from B that are divisible by items in A
      # associate/correlate each number in A with the ones are divisible by it from B
      it 'correctly outputs a numerical correlation for integer modulo' do
        numbers = [1, 2, 3, 4]
        fixed_test_numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        result = h.correlate(numbers, fixed_test_numbers){|a,b| b % a == 0}
        expect(result).to eq({ 1 => [1, 2, 3, 4, 5, 6, 7, 8, 9],
                               2 => [2 ,4, 6, 8],
                               3 => [3, 6, 9],
                               4 => [4, 8],
                              })
      end

    end

  end

  context 'deep correlation methods' do

    context 'set correlation methods' do
      # create identical sets at first
      let(:set_a){ TestModelFactory.create_list(2, prefix: 'A') }
      let(:set_b){ TestModelFactory.create_list(8, prefix: 'B') }

      let(:strategies){[ # correlation strategies
        lambda{|a,b| a.id == b.id },
        lambda{|a,b| a.email == b.email },
        lambda{|a,b| a.first_name == b.first_name },
      ]}

      let(:disambiguation_strategies){[ # disambiguation strategies
        lambda{|a,bs| bs.select{|b| b.id == a.id} },
        lambda{|a,bs| bs.select{|b| b.email == a.email} },
        lambda{|a,bs| bs.select{|b| b.first_name == a.first_name} },
      ]}

      before do
        # Assign the first 4 `b`s the id of the first `a`
        set_b_first_4 = set_b.first(4)
        set_b_last_4 = set_b.last(4)

        set_b_first_4.each{|b| b.id = set_a.first.id}
        # Assign the last 4 `b`s the id of the last `a`
        set_b_last_4.each{|b| b.id = set_a.last.id}

        # Assign the first 2 of the first 4 the same email
        set_b_first_4.first(2).each{|b| b.email = set_a.first.email}

        # Assign the first 2 of the last 4 the same email as well
        set_b_last_4.first(2).each{|b| b.email = set_a.last.email}

        # finally, make the first of each block of two, with the same email, the same by
        # their first_name
        set_b_first_4.first(2).first.first_name = set_a.first.first_name
        set_b_last_4.first(2).first.first_name = set_a.last.first_name

        # Given those rules, the ones that match by the same data are
        # A[0] == B [0] and A[1] == B[4]

      end

      describe '#deep_correlation_mapping' do
        it 'does a deep correlation and returns an comprehensible report' do
          result = h.deep_correlation_mapping(set_a, set_b, *strategies)
          expect(result[:summary]).to eq({:one_to_one_count => 2, :one_to_many_count => 0, :no_correlation_a_count => 0, :no_correlation_b_count => 6})
          expect(result[:one_to_one]).to eq({set_a[0] => set_b[0], set_a[1] => set_b[4]})
          expect(result[:one_to_many]).to eq({})
          expect(result[:no_correlation_a]).to eq([])
          expect(result[:no_correlation_b]).to eq(set_b[1..3] + set_b[5..7])
        end

        it 'applies correlation strategies while the block evaluates to true' do
          result = h.deep_correlation_mapping(set_a, set_b, *strategies){|a,bs| bs.count > 2}
          expect(result[:summary]).to eq({:one_to_one_count => 0, :one_to_many_count => 2, :no_correlation_a_count=>0, :no_correlation_b_count=>4})
          expect(result[:one_to_one]).to eq({})
          expect(result[:one_to_many]).to eq({set_a[0] => [set_b[0], set_b[1]], set_a[1] => [set_b[4], set_b[5]]})
          expect(result[:no_correlation_a]).to eq([])
          expect(result[:no_correlation_b]).to eq(set_b[2..3] + set_b[6..7])
        end
      end

      describe '#deep_correlation' do

        it 'applies all correlation strategies when no block is passed' do
          result = h.deep_correlation(set_a, set_b, *strategies)
          expect(result).to eq ({set_a[0] => [set_b[0]], set_a[1] => [set_b[4]]})
        end

        it 'applies correlation strategies while the block evaluates to true' do
          result = h.deep_correlation(set_a, set_b, *strategies){|a,bs| bs.count > 2}
          expect(result).to eq ({set_a[0] => [set_b[0], set_b[1]], set_a[1] => [set_b[4], set_b[5]]})
        end

      end

      describe '#deep_disambiguation' do

        it 'applies all correlation strategies when no block is passed' do
          result = h.deep_disambiguation(set_a, set_b, *disambiguation_strategies)
          expect(result).to eq ({set_a[0] => [set_b[0]], set_a[1] => [set_b[4]]})
        end

        it 'applies correlation strategies while the block evaluates to true' do
          result = h.deep_disambiguation(set_a, set_b, *disambiguation_strategies){|a,bs| bs.count > 2}
          expect(result).to eq ({set_a[0] => [set_b[0], set_b[1]], set_a[1] => [set_b[4], set_b[5]]})
        end

      end

      describe '#quick_correlation_and_disambiguation' do

        let(:correlation_strategy){lambda{|a,b| a.id == b.id} } # Match ids
        let(:pick_last){lambda{|a,bs| [bs.last]}} # Pick last element
        let(:sort_reverse_and_pick_first){lambda{|a,bs| [bs.sort{|a,b| a.first_name <=> b.first_name}.reverse.first]}} # sorting by name
        let(:nullify){lambda{|a,bs| [nil] * bs.count }} # make all objects nil! -> tests the "stop"

        it 'correlates and then disambiguates until it reaches the most it can one-to-one, when no block is passed' do
          # correlates, picks the last element, and it stops before nullifying it/them
          result = h.quick_correlation_and_disambiguation(set_a, set_b, correlation_strategy, *[pick_last, nullify])
          expect(result).to eq ({set_a[0] => [set_b[3]], set_a[1] => [set_b[7]]})
        end

        it 'correlates and then applies all disambiguation strategies if its block always evaluates to true' do
          # correlates, picks the last element, and it does not stop, nullifying the results at the end
          result = h.quick_correlation_and_disambiguation(set_a, set_b, correlation_strategy, *[pick_last, nullify]){|a,bs| true}
          expect(result).to eq ({set_a[0] => [nil], set_a[1] => [nil]})
        end
      end


      context 'with reporters' do

        let(:correlation_strategy){lambda{|a,b| a.id == b.id} } # Match ids
        let(:pick_last){lambda{|a,bs| [bs.last]}} # Pick last element
        let(:sort_reverse_and_pick_first){lambda{|a,bs| [bs.sort{|a,b| a.first_name <=> b.first_name}.reverse.first]}} # sorting by name
        let(:nullify){lambda{|a,bs| [nil] * bs.count }} # make all objects nil! -> tests the "stop"

        let(:noop_reporter){ lambda{|x| x} }
        let(:id_reporter){ lambda{|x| x.id} }
        let(:email_reporter){ lambda{|x| x.email} }

        describe '#quick_correlation_and_disambiguation_mapping_with_reporters' do

          it 'can disambiguate using a correlation operation and use reporters too' do
            result = h.quick_correlation_and_disambiguation_mapping_with_reporters(set_a, set_b, email_reporter, email_reporter, correlation_strategy, *[pick_last, nullify])
            expect(result).to eq({
                       :summary => {
                      :one_to_one_count => 2,
                     :one_to_many_count => 0,
                :no_correlation_a_count => 0,
                :no_correlation_b_count => 6
              },
                    :one_to_one => {
                "A_0@test.com" => "B_3@test.com",
                "A_1@test.com" => "B_7@test.com"
              },
                   :one_to_many => {},
              :no_correlation_a => [],
              :no_correlation_b => [
                "A_0@test.com",
                "A_0@test.com",
                "B_2@test.com",
                "A_1@test.com",
                "A_1@test.com",
                "B_6@test.com"
              ]
            })
          end

          it 'can disambiguate using a correlation operation and use reporters too, does sorting and all that' do
            result = h.quick_correlation_and_disambiguation_mapping_with_reporters(set_a, set_b, id_reporter, email_reporter, correlation_strategy, *[sort_reverse_and_pick_first, nullify])
            expect(result).to eq({
                       :summary => {
                      :one_to_one_count => 2,
                     :one_to_many_count => 0,
                :no_correlation_a_count => 0,
                :no_correlation_b_count => 6
              },
                    :one_to_one => {
                0 => "B_3@test.com",
                1 => "B_7@test.com"
              },
                   :one_to_many => {},
              :no_correlation_a => [],
              :no_correlation_b => [
                "A_0@test.com",
                "A_0@test.com",
                "B_2@test.com",
                "A_1@test.com",
                "A_1@test.com",
                "B_6@test.com"
              ]
            })
          end

        end

        describe '#deep_disambiguation_mapping_with_reporters' do

          it 'can disambiguate using a correlation operation and use reporters too' do
            result = h.deep_disambiguation_mapping_with_reporters(set_a, set_b, email_reporter, email_reporter, lambda{|a,bs| h.correlate_element(a,bs){|a,b| a.id == b.id} })
            expect(result).to eq({
              :summary=>{
                :one_to_one_count=>0,
                :one_to_many_count=>2,
                :no_correlation_a_count=>0,
                :no_correlation_b_count=>0},
              :one_to_one=>{},
              :one_to_many=>{"A_0@test.com"=>["A_0@test.com", "A_0@test.com", "B_2@test.com", "B_3@test.com"],
                             "A_1@test.com"=>["A_1@test.com", "A_1@test.com", "B_6@test.com", "B_7@test.com"]},
              :no_correlation_a=>[],
              :no_correlation_b=>[]})
          end

          it 'can choose the last element of an array of possibilities, and correctly output the one-to-one match' do
            result = h.deep_disambiguation_mapping_with_reporters(set_a, set_b, email_reporter, email_reporter, lambda{|a,bs| h.correlate_element(a,bs){|a,b| a.id == b.id} }, lambda{|a,bs| [bs.last]})
            expect(result).to eq({
              :summary=>{
                :one_to_one_count=>2,
                :one_to_many_count=>0,
                :no_correlation_a_count=>0,
                :no_correlation_b_count=>6},
              :one_to_one=>{"A_0@test.com"=>"B_3@test.com",
                            "A_1@test.com"=>"B_7@test.com"},
              :one_to_many=>{},
              :no_correlation_a=>[],
              :no_correlation_b=>["A_0@test.com", "A_0@test.com", "B_2@test.com", "A_1@test.com", "A_1@test.com", "B_6@test.com"]})
          end

        end

        describe '#deep_correlation_mapping_with_reporters' do
          it 'does a deep correlation and returns an comprehensible report, with reporters' do
            result = h.deep_correlation_mapping_with_reporters(set_a, set_b, email_reporter, email_reporter, *strategies)
            # expect(result[:summary]).to eq({:one_to_one_count => 2, :one_to_many_count => 0, :no_correlation_a_count => 0, :no_correlation_b_count => 6})
            # expect(result[:one_to_one]).to eq({set_a[0] => set_b[0], set_a[1] => set_b[4]})
            # expect(result[:one_to_many]).to eq({})
            # expect(result[:no_correlation_a]).to eq([])
            # expect(result[:no_correlation_b]).to eq(set_b[1..3] + set_b[5..7])
          end

          it 'applies correlation strategies while the block evaluates to true' do
            result = h.deep_correlation_mapping_with_reporters(set_a, set_b, email_reporter, email_reporter, *strategies){|a,bs| bs.count > 2}
            # expect(result[:summary]).to eq({:one_to_one_count => 0, :one_to_many_count => 2, :no_correlation_a_count=>0, :no_correlation_b_count=>4})
            # expect(result[:one_to_one]).to eq({})
            # expect(result[:one_to_many]).to eq({set_a[0] => [set_b[0], set_b[1]], set_a[1] => [set_b[4], set_b[5]]})
            # expect(result[:no_correlation_a]).to eq([])
            # expect(result[:no_correlation_b]).to eq(set_b[2..3] + set_b[6..7])
          end
        end

        describe '#deep_correlation_with_reporters' do

          context 'with noop reporters' do

            it 'applies all correlation strategies when no block is passed, exactly as when no reporter is used' do
              result = h.deep_correlation_with_reporters(set_a, set_b, noop_reporter, noop_reporter, *strategies)
              expect(result).to eq ({set_a[0] => [set_b[0]], set_a[1] => [set_b[4]]})
            end

            it 'applies correlation strategies while the block evaluates to true, exactly as when no reporter is used' do
              result = h.deep_correlation_with_reporters(set_a, set_b, noop_reporter, noop_reporter, *strategies){|a,bs| bs.count > 2}
              expect(result).to eq ({set_a[0] => [set_b[0], set_b[1]], set_a[1] => [set_b[4], set_b[5]]})
            end

          end

          context 'with id reporters' do

            it 'applies all correlation strategies when no block is passed, and only outputs id mappings' do
              result = h.deep_correlation_with_reporters(set_a, set_b, id_reporter, id_reporter, *strategies)
              expect(result).to eq ({0 => [0], 1 => [1]})
            end

            it 'applies correlation strategies while the block evaluates to true, and only outputs id mappings' do
              result = h.deep_correlation_with_reporters(set_a, set_b, id_reporter, id_reporter, *strategies){|a,bs| bs.count > 2}
              expect(result).to eq ({0 => [0,0], 1 => [1,1]})
            end

          end

          context 'with email reporters' do

            it 'applies all correlation strategies when no block is passed, and only outputs email mappings' do
              result = h.deep_correlation_with_reporters(set_a, set_b, email_reporter, email_reporter, *strategies)
              expect(result).to eq ({"A_0@test.com" => ["A_0@test.com"], "A_1@test.com" => ["A_1@test.com"]})
            end

            it 'applies correlation strategies while the block evaluates to true, and only outputs email mappings' do
              result = h.deep_correlation_with_reporters(set_a, set_b, email_reporter, email_reporter, *strategies){|a,bs| bs.count > 2}
              expect(result).to eq ({"A_0@test.com"=>["A_0@test.com", "A_0@test.com"], "A_1@test.com"=>["A_1@test.com", "A_1@test.com"]})
            end

          end

          context 'with mixed id and email reporters' do

            it 'applies all correlation strategies when no block is passed, and only outputs email mappings' do
              result = h.deep_correlation_with_reporters(set_a, set_b, id_reporter, email_reporter, *strategies)
              expect(result).to eq ({0 => ["A_0@test.com"], 1 => ["A_1@test.com"]})
            end

            it 'applies correlation strategies while the block evaluates to true, and only outputs email mappings' do
              result = h.deep_correlation_with_reporters(set_a, set_b, id_reporter, email_reporter, *strategies){|a,bs| bs.count > 2}
              expect(result).to eq ({ 0 =>["A_0@test.com", "A_0@test.com"], 1 => ["A_1@test.com", "A_1@test.com"]})
            end

          end


        end

      end

    end

    context 'element correlation methods' do

      let(:strategies){[
          lambda{|a,b| b < 6 },
          lambda{|a,b| b < 5 },
          lambda{|a,b| b < 4 },
        ]}

      describe '#deep_element_correlation' do

        it 'applies all correlation strategies when no block is passed' do
          result = h.deep_element_correlation(1, [1,2,3,4,5,6], *strategies)
          expect(result).to eq ([1,2,3])
        end

        it 'raises an error if a non-callable strategy is present' do
          expect{h.deep_element_correlation(1, [1,2,3,4,5,6], *[lambda{|a,b| true}, "strategy"])}.to raise_error('Correlation strategies are not all callable objects!')
        end

        it 'applies correlation strategies while the block evaluates to true' do
          result = h.deep_element_correlation(1, [1,2,3,4,5,6], *strategies){|a,bs| bs.sum > 10 }
          expect(result).to eq ([1,2,3,4])
        end
      end

      context 'with reporters' do

        let(:reporter){ lambda{|b| b.to_s} }
        let(:element){ 1 }
        let(:set_b){ [1,2,3,4,5,6] }

        describe '#deep_element_correlation_with_reporter' do

          it 'applies all correlation strategies when no block is passed' do
            result = h.deep_element_correlation_with_reporter(element, set_b, reporter, *strategies)
            expect(result).to eq (['1','2','3'])
          end

          it 'raises an error if a non-callable strategy is present' do
            expect{h.deep_element_correlation_with_reporter(element, set_b, reporter, *[lambda{|a,b| true}, "strategy"])}.to raise_error('Correlation strategies are not all callable objects!')
          end

          it 'applies correlation strategies while the block evaluates to true' do
            result = h.deep_element_correlation_with_reporter(element, set_b, reporter, *strategies){|a,bs| bs.sum > 10 }
            expect(result).to eq (['1','2','3','4'])
          end
        end
      end

    end

  end


  # return only those which have values (full)
  def f(hash)
    hash.select{|k,v| v.present?}
  end

  # return only those which DON'T have values (empty)
  def e(hash)
    hash.reject{|k,v| v.present?}
  end

  # this method checks if the attributes are the same
  # but substituting the test prefixes
  def test_same_non_prefixed_attributes(a, b)
    a.attributes.map do |k, a_attribute|
      b_attribute = b.attributes[k]
      if b_attribute.is_a? String
        b_attribute = b_attribute.gsub(/^B_/, 'A_')
      end
      a_attribute == b_attribute
    end.all?
  end

end
