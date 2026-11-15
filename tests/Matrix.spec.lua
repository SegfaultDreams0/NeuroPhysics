return function()
    local Matrix = require(game.ServerScriptService.NeuroPhysics).Matrix

    describe("NeuroPhysics.Matrix", function()
        it("creates an identity matrix", function()
            local Identity = Matrix.new(2, 2):Identity()
            expect(Identity.Data[1][1]).to.equal(1)
            expect(Identity.Data[1][2]).to.equal(0)
            expect(Identity.Data[2][1]).to.equal(0)
            expect(Identity.Data[2][2]).to.equal(1)
        end)

        it("transposes a matrix", function()
            local A = Matrix.new(2, 3)
            A.Data[1] = {1, 2, 3}
            A.Data[2] = {4, 5, 6}

            local T = A:Transpose()
            expect(T.Rows).to.equal(3)
            expect(T.Columns).to.equal(2)
            expect(T.Data[3][2]).to.equal(6)
        end)

        it("multiplies compatible matrices", function()
            local A = Matrix.new(2, 2)
            A.Data[1] = {1, 2}
            A.Data[2] = {3, 4}

            local B = Matrix.new(2, 1)
            B.Data[1] = {5}
            B.Data[2] = {6}

            local Result = A:Multiply(B)
            expect(Result.Data[1][1]).to.equal(17)
            expect(Result.Data[2][1]).to.equal(39)
        end)

        it("calculates a determinant", function()
            local A = Matrix.new(2, 2)
            A.Data[1] = {4, 7}
            A.Data[2] = {2, 6}
            expect(A:Determinant()).to.equal(10)
        end)

        it("returns nil for a singular matrix inverse", function()
            local A = Matrix.new(2, 2)
            A.Data[1] = {1, 2}
            A.Data[2] = {2, 4}
            expect(A:Inverse()).to.equal(nil)
        end)
    end)
end
