<!-- SPDX-License-Identifier: MIT -->

<template>
    <div class="example">
        <h1>Hello, Vue!</h1>
        <p>Welcome to your MIT licensed Vue component.</p>
        <button @click="increment">Clicked {{ count }} times</button>
    </div>
</template>

<script>
export default {
    name: 'Example',
    data() {
        return {
            count: 0
        };
    },
    methods: {
        increment() {
            this.count++;
        }
    }
};
</script>

<style scoped>
.example {
    font-family: Arial, sans-serif;
    padding: 2rem;
    background: #f9f9f9;
    border-radius: 8px;
}
button {
    margin-top: 1rem;
    padding: 0.5rem 1rem;
    font-size: 1rem;
}
</style>