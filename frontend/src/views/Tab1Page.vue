<template>
  <ion-page>
    <ion-header>
      <ion-toolbar>
        <ion-title>Pollen</ion-title>
      </ion-toolbar>
    </ion-header>
    <ion-content :fullscreen="true">
      <ion-header collapse="condense">
        <ion-toolbar>
          <ion-title size="large">Pollen</ion-title>
        </ion-toolbar>
      </ion-header>
      <DynamicScroller class="scroller" :items="posts" :minItemSize="360" keyField="title">
        <template #default="{ item }">
          <PostCard :item="item" />
        </template>
      </DynamicScroller>
    </ion-content>
  </ion-page>
</template>

<script lang="ts">
import { defineComponent, ref } from 'vue';
import { IonPage, IonHeader, IonToolbar, IonTitle, IonContent } from '@ionic/vue';

import { DynamicScroller } from 'vue-virtual-scroller';

import PostCard from '@/components/PostCard.vue';

export default defineComponent({
  name: 'Tab1Page',
  components: {
    IonHeader,
    IonToolbar,
    IonTitle,
    IonContent,
    IonPage,
    DynamicScroller,
    PostCard,
  },
  setup() {
    const posts = ref([] as any[]);

    posts.value = [
      {
        title: 'Waves in the Winter 1',
        subtitle: 'Alex Romanoff',
        image: 'https://c.wallhere.com/photos/0e/e1/surfing_waves_sea_monochrome-247782.jpg!d',
      },
      {
        title: 'Waves in the Winter 2',
        subtitle: 'Alex Romanoff',
        image: 'https://c.wallhere.com/photos/0e/e1/surfing_waves_sea_monochrome-247782.jpg!d',
      },
      {
        title: 'Waves in the Winter 3',
        subtitle: 'Alex Romanoff',
        image: 'https://c.wallhere.com/photos/0e/e1/surfing_waves_sea_monochrome-247782.jpg!d',
      },
    ];

    return { posts };
  },
});
</script>
